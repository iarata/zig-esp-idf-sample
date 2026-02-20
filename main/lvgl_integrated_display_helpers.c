#include <stdint.h>

#include "driver/i2c_master.h"
#include "driver/spi_master.h"
#include "esp_check.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_vendor.h"
#include "esp_log.h"
#include "esp_lvgl_port.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "waveshare_axp2101.h"

#include "esp_lcd_sh8601.h"
#include "esp_lcd_touch_ft5x06.h"

static const char *TAG = "zig_lvgl_disp";

static const spi_host_device_t LCD_HOST = SPI2_HOST;
static const i2c_port_num_t TOUCH_I2C_PORT = I2C_NUM_0;
static const gpio_num_t TOUCH_SDA = GPIO_NUM_15;
static const gpio_num_t TOUCH_SCL = GPIO_NUM_14;
static const gpio_num_t TOUCH_INT = GPIO_NUM_21;
static const uint32_t TOUCH_FREQ_HZ = 400000;
static const int TOUCH_INIT_RETRIES = 5;
static const int TOUCH_RETRY_DELAY_MS = 80;
static const int POWER_SETTLE_DELAY_MS = 350;
static const int LABEL_SIDE_PADDING = 16;

static const gpio_num_t LCD_SCLK = GPIO_NUM_11;
static const gpio_num_t LCD_D0 = GPIO_NUM_4;
static const gpio_num_t LCD_D1 = GPIO_NUM_5;
static const gpio_num_t LCD_D2 = GPIO_NUM_6;
static const gpio_num_t LCD_D3 = GPIO_NUM_7;
static const gpio_num_t LCD_CS = GPIO_NUM_12;
static const gpio_num_t LCD_RST = GPIO_NUM_NC;

static const uint32_t LCD_H_RES = 368;
static const uint32_t LCD_V_RES = 448;
static const uint32_t LVGL_BUF_LINES = 48;

static const uint8_t sh8601_cmd_11[] = {0x00};
static const uint8_t sh8601_cmd_44[] = {0x01, 0xD1};
static const uint8_t sh8601_cmd_35[] = {0x00};
static const uint8_t sh8601_cmd_53[] = {0x20};
static const uint8_t sh8601_cmd_2a[] = {0x00, 0x00, 0x01, 0x6F};
static const uint8_t sh8601_cmd_2b[] = {0x00, 0x00, 0x01, 0xBF};
static const uint8_t sh8601_cmd_51_00[] = {0x00};
static const uint8_t sh8601_cmd_51_ff[] = {0xFF};

static const sh8601_lcd_init_cmd_t sh8601_init_cmds[] = {
    {.cmd = 0x11, .data = sh8601_cmd_11, .data_bytes = sizeof(sh8601_cmd_11), .delay_ms = 120},
    {.cmd = 0x44, .data = sh8601_cmd_44, .data_bytes = sizeof(sh8601_cmd_44), .delay_ms = 0},
    {.cmd = 0x35, .data = sh8601_cmd_35, .data_bytes = sizeof(sh8601_cmd_35), .delay_ms = 0},
    {.cmd = 0x53, .data = sh8601_cmd_53, .data_bytes = sizeof(sh8601_cmd_53), .delay_ms = 10},
    {.cmd = 0x2A, .data = sh8601_cmd_2a, .data_bytes = sizeof(sh8601_cmd_2a), .delay_ms = 0},
    {.cmd = 0x2B, .data = sh8601_cmd_2b, .data_bytes = sizeof(sh8601_cmd_2b), .delay_ms = 0},
    {.cmd = 0x51, .data = sh8601_cmd_51_00, .data_bytes = sizeof(sh8601_cmd_51_00), .delay_ms = 10},
    {.cmd = 0x29, .data = NULL, .data_bytes = 0, .delay_ms = 10},
    {.cmd = 0x51, .data = sh8601_cmd_51_ff, .data_bytes = sizeof(sh8601_cmd_51_ff), .delay_ms = 0},
};

// SH8601 requires even start/end boundaries for clean partial updates.
static void zig_lvgl_rounder_cb(lv_area_t *area)
{
    int32_t x1 = area->x1;
    int32_t x2 = area->x2;
    int32_t y1 = area->y1;
    int32_t y2 = area->y2;

    area->x1 = (x1 >> 1) << 1;
    area->y1 = (y1 >> 1) << 1;
    area->x2 = ((x2 >> 1) << 1) + 1;
    area->y2 = ((y2 >> 1) << 1) + 1;
}

void zig_lvgl_apply_test_label_style(lv_obj_t *label)
{
    if (label == NULL) {
        return;
    }

#if LV_FONT_MONTSERRAT_48
    lv_obj_set_style_text_font(label, &lv_font_montserrat_48, 0);
#elif LV_FONT_MONTSERRAT_40
    lv_obj_set_style_text_font(label, &lv_font_montserrat_40, 0);
#elif LV_FONT_MONTSERRAT_32
    lv_obj_set_style_text_font(label, &lv_font_montserrat_32, 0);
#elif LV_FONT_MONTSERRAT_28
    lv_obj_set_style_text_font(label, &lv_font_montserrat_28, 0);
#elif LV_FONT_MONTSERRAT_24
    lv_obj_set_style_text_font(label, &lv_font_montserrat_24, 0);
#endif

    lv_obj_set_style_text_align(label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(label, lv_color_hex(0x000000), 0);
    lv_obj_set_style_text_opa(label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_line_space(label, 6, 0);
    lv_obj_set_width(label, lv_pct(100));
    lv_label_set_long_mode(label, LV_LABEL_LONG_WRAP);
}

lv_obj_t *zig_lvgl_create_centered_label(const char *text)
{
    lv_obj_t *screen = lv_screen_active();
    if (screen == NULL) {
        return NULL;
    }

    lv_obj_t *container = lv_obj_create(screen);
    if (container == NULL) {
        return NULL;
    }

    lv_obj_remove_style_all(container);
    lv_obj_set_size(container, lv_pct(100), lv_pct(100));
    lv_obj_set_style_bg_opa(container, LV_OPA_TRANSP, 0);
    lv_obj_set_style_border_width(container, 0, 0);
    lv_obj_set_style_pad_left(container, LABEL_SIDE_PADDING, 0);
    lv_obj_set_style_pad_right(container, LABEL_SIDE_PADDING, 0);
    lv_obj_set_style_pad_top(container, 0, 0);
    lv_obj_set_style_pad_bottom(container, 0, 0);
    lv_obj_set_style_radius(container, 0, 0);
    lv_obj_set_scrollbar_mode(container, LV_SCROLLBAR_MODE_OFF);
    lv_obj_clear_flag(container, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_flex_flow(container, LV_FLEX_FLOW_COLUMN);
    lv_obj_set_flex_align(container, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

    lv_obj_t *label = lv_label_create(container);
    if (label == NULL) {
        return NULL;
    }

    zig_lvgl_apply_test_label_style(label);
    lv_label_set_text(label, (text != NULL) ? text : "Zig + LVGL");
    lv_obj_update_layout(container);
    return label;
}

esp_err_t zig_lvgl_touch_amoled_1_8_init(lv_display_t **out_disp, lv_indev_t **out_touch)
{
    if (out_disp == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    *out_disp = NULL;
    if (out_touch != NULL) {
        *out_touch = NULL;
    }

    ESP_RETURN_ON_ERROR(
        waveshare_axp2101_init(TOUCH_I2C_PORT, TOUCH_SDA, TOUCH_SCL, TOUCH_FREQ_HZ),
        TAG,
        "AXP2101 init failed");
    ESP_RETURN_ON_ERROR(
        waveshare_axp2101_apply_touch_amoled_1_8_defaults(),
        TAG,
        "Failed to apply AXP2101 AMOLED defaults");
    vTaskDelay(pdMS_TO_TICKS(POWER_SETTLE_DELAY_MS));

    const spi_bus_config_t bus_cfg = SH8601_PANEL_BUS_QSPI_CONFIG(
        LCD_SCLK,
        LCD_D0,
        LCD_D1,
        LCD_D2,
        LCD_D3,
        LCD_H_RES * LVGL_BUF_LINES * sizeof(uint16_t));
    ESP_RETURN_ON_ERROR(
        spi_bus_initialize(LCD_HOST, &bus_cfg, SPI_DMA_CH_AUTO),
        TAG,
        "SPI bus init failed");

    esp_lcd_panel_io_handle_t lcd_io = NULL;
    const esp_lcd_panel_io_spi_config_t io_cfg = SH8601_PANEL_IO_QSPI_CONFIG(LCD_CS, NULL, NULL);
    ESP_RETURN_ON_ERROR(
        esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST, &io_cfg, &lcd_io),
        TAG,
        "Failed to create SH8601 panel IO");

    const sh8601_vendor_config_t vendor_cfg = {
        .init_cmds = sh8601_init_cmds,
        .init_cmds_size = sizeof(sh8601_init_cmds) / sizeof(sh8601_init_cmds[0]),
        .flags = {
            .use_qspi_interface = 1,
        },
    };
    const esp_lcd_panel_dev_config_t panel_cfg = {
        .reset_gpio_num = LCD_RST,
        .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_RGB,
        .bits_per_pixel = 16,
        .vendor_config = (void *)&vendor_cfg,
    };

    esp_lcd_panel_handle_t panel = NULL;
    ESP_RETURN_ON_ERROR(
        esp_lcd_new_panel_sh8601(lcd_io, &panel_cfg, &panel),
        TAG,
        "Failed to create SH8601 panel");
    ESP_RETURN_ON_ERROR(esp_lcd_panel_reset(panel), TAG, "SH8601 reset failed");
    ESP_RETURN_ON_ERROR(esp_lcd_panel_init(panel), TAG, "SH8601 init failed");
    ESP_RETURN_ON_ERROR(esp_lcd_panel_disp_on_off(panel, true), TAG, "SH8601 display on failed");

    const lvgl_port_display_cfg_t disp_cfg = {
        .io_handle = lcd_io,
        .panel_handle = panel,
        .buffer_size = LCD_H_RES * LVGL_BUF_LINES,
        .double_buffer = true,
        .trans_size = 0,
        .hres = LCD_H_RES,
        .vres = LCD_V_RES,
        .monochrome = false,
        .rotation = {
            .swap_xy = false,
            .mirror_x = false,
            .mirror_y = false,
        },
        .rounder_cb = zig_lvgl_rounder_cb,
#if LVGL_VERSION_MAJOR >= 9
        .color_format = LV_COLOR_FORMAT_RGB565,
#endif
        .flags = {
            .buff_dma = 1,
            .buff_spiram = 0,
            .sw_rotate = 0,
#if LVGL_VERSION_MAJOR >= 9
            .swap_bytes = 1,
#endif
            .full_refresh = 0,
            .direct_mode = 0,
        },
    };

    lv_display_t *disp = lvgl_port_add_disp(&disp_cfg);
    ESP_RETURN_ON_FALSE(disp != NULL, ESP_FAIL, TAG, "lvgl_port_add_disp failed");
    *out_disp = disp;

    if (out_touch != NULL) {
        *out_touch = NULL;
    }

    i2c_master_bus_handle_t i2c_bus = NULL;
    esp_err_t bus_err = i2c_master_get_bus_handle(TOUCH_I2C_PORT, &i2c_bus);
    if (bus_err != ESP_OK) {
        ESP_LOGW(TAG, "Touch disabled: failed to get I2C bus handle (%s)", esp_err_to_name(bus_err));
        return ESP_OK;
    }

    esp_lcd_panel_io_i2c_config_t touch_io_cfg = ESP_LCD_TOUCH_IO_I2C_FT5x06_CONFIG();
    touch_io_cfg.scl_speed_hz = TOUCH_FREQ_HZ;

    const esp_lcd_touch_config_t touch_cfg = {
        .x_max = LCD_H_RES,
        .y_max = LCD_V_RES,
        .rst_gpio_num = GPIO_NUM_NC,
        .int_gpio_num = TOUCH_INT,
        .levels = {
            .reset = 0,
            .interrupt = 0,
        },
        .flags = {
            .swap_xy = 0,
            .mirror_x = 0,
            .mirror_y = 0,
        },
    };

    for (int attempt = 1; attempt <= TOUCH_INIT_RETRIES; ++attempt) {
        esp_lcd_panel_io_handle_t touch_io = NULL;
        esp_err_t io_err = esp_lcd_new_panel_io_i2c(i2c_bus, &touch_io_cfg, &touch_io);
        if (io_err != ESP_OK) {
            ESP_LOGW(
                TAG,
                "Touch IO init attempt %d/%d failed (%s)",
                attempt,
                TOUCH_INIT_RETRIES,
                esp_err_to_name(io_err));
            vTaskDelay(pdMS_TO_TICKS(TOUCH_RETRY_DELAY_MS));
            continue;
        }

        esp_lcd_touch_handle_t touch_handle = NULL;
        esp_err_t touch_err = esp_lcd_touch_new_i2c_ft5x06(touch_io, &touch_cfg, &touch_handle);
        if (touch_err != ESP_OK) {
            ESP_LOGW(
                TAG,
                "Touch controller init attempt %d/%d failed (%s)",
                attempt,
                TOUCH_INIT_RETRIES,
                esp_err_to_name(touch_err));
            esp_lcd_panel_io_del(touch_io);
            vTaskDelay(pdMS_TO_TICKS(TOUCH_RETRY_DELAY_MS));
            continue;
        }

        const lvgl_port_touch_cfg_t lvgl_touch_cfg = {
            .disp = disp,
            .handle = touch_handle,
            .scale = {
                .x = 1.0f,
                .y = 1.0f,
            },
        };
        lv_indev_t *touch_indev = lvgl_port_add_touch(&lvgl_touch_cfg);
        if (touch_indev == NULL) {
            ESP_LOGW(TAG, "Touch driver initialized but lvgl_port_add_touch failed");
            esp_lcd_touch_del(touch_handle);
            esp_lcd_panel_io_del(touch_io);
            return ESP_OK;
        }

        if (out_touch != NULL) {
            *out_touch = touch_indev;
        }
        ESP_LOGI(TAG, "Touch initialized on attempt %d/%d", attempt, TOUCH_INIT_RETRIES);
        return ESP_OK;
    }

    ESP_LOGW(TAG, "Touch disabled after %d failed init attempts", TOUCH_INIT_RETRIES);
    return ESP_OK;
}
