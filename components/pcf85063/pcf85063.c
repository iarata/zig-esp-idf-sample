#include "pcf85063.h"

#include <stdbool.h>

#include "soc/soc_caps.h"

#define I2C_TIMEOUT_MS 1000

typedef struct {
    bool initialized;
    i2c_master_bus_handle_t bus_handle;
    i2c_master_dev_handle_t dev_handle;
} pcf85063_i2c_ctx_t;

static pcf85063_i2c_ctx_t s_i2c_ctx[SOC_I2C_NUM];

static pcf85063_i2c_ctx_t *pcf85063_get_ctx(i2c_port_num_t port)
{
    if (port < 0 || port >= SOC_I2C_NUM) {
        return NULL;
    }
    return &s_i2c_ctx[port];
}

static uint8_t bcd_to_dec(uint8_t value)
{
    return ((value >> 4) * 10) + (value & 0x0F);
}

static uint8_t dec_to_bcd(uint8_t value)
{
    return ((value / 10) << 4) | (value % 10);
}

esp_err_t pcf85063_init(i2c_port_num_t port, gpio_num_t sda, gpio_num_t scl, uint32_t freq_hz)
{
    if (freq_hz == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    pcf85063_i2c_ctx_t *ctx = pcf85063_get_ctx(port);
    if (ctx == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    if (ctx->initialized) {
        return ESP_OK;
    }

    esp_err_t err = i2c_master_get_bus_handle(port, &ctx->bus_handle);
    if (err == ESP_ERR_INVALID_STATE) {
        i2c_master_bus_config_t bus_cfg = {
            .i2c_port = port,
            .sda_io_num = sda,
            .scl_io_num = scl,
            .clk_source = I2C_CLK_SRC_DEFAULT,
            .glitch_ignore_cnt = 7,
            .flags.enable_internal_pullup = true,
        };
        err = i2c_new_master_bus(&bus_cfg, &ctx->bus_handle);
    }
    if (err != ESP_OK) {
        return err;
    }

    i2c_device_config_t dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = PCF85063_I2C_ADDRESS,
        .scl_speed_hz = freq_hz,
    };
    err = i2c_master_bus_add_device(ctx->bus_handle, &dev_cfg, &ctx->dev_handle);
    if (err != ESP_OK) {
        ctx->bus_handle = NULL;
        ctx->dev_handle = NULL;
        return err;
    }

    ctx->initialized = true;
    return ESP_OK;
}

esp_err_t pcf85063_read_reg(i2c_port_num_t port, uint8_t reg_addr, uint8_t *data, size_t len)
{
    if (data == NULL || len == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    pcf85063_i2c_ctx_t *ctx = pcf85063_get_ctx(port);
    if (ctx == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!ctx->initialized || ctx->dev_handle == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    return i2c_master_transmit_receive(
        ctx->dev_handle,
        &reg_addr,
        sizeof(reg_addr),
        data,
        len,
        I2C_TIMEOUT_MS);
}

esp_err_t pcf85063_write_reg(i2c_port_num_t port, uint8_t reg_addr, const uint8_t *data, size_t len)
{
    if (data == NULL || len == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    pcf85063_i2c_ctx_t *ctx = pcf85063_get_ctx(port);
    if (ctx == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!ctx->initialized || ctx->dev_handle == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    i2c_master_transmit_multi_buffer_info_t tx_bufs[] = {
        {
            .write_buffer = &reg_addr,
            .buffer_size = sizeof(reg_addr),
        },
        {
            .write_buffer = data,
            .buffer_size = len,
        },
    };

    return i2c_master_multi_buffer_transmit(
        ctx->dev_handle,
        tx_bufs,
        sizeof(tx_bufs) / sizeof(tx_bufs[0]),
        I2C_TIMEOUT_MS);
}

esp_err_t pcf85063_get_datetime(i2c_port_num_t port, pcf85063_datetime_t *out_datetime)
{
    if (out_datetime == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t data[7] = {0};
    esp_err_t err = pcf85063_read_reg(port, 0x04, data, sizeof(data));
    if (err != ESP_OK) {
        return err;
    }

    out_datetime->seconds = bcd_to_dec(data[0] & 0x7F);
    out_datetime->minutes = bcd_to_dec(data[1] & 0x7F);
    out_datetime->hours = bcd_to_dec(data[2] & 0x3F);
    out_datetime->day = bcd_to_dec(data[3] & 0x3F);
    out_datetime->weekday = bcd_to_dec(data[4] & 0x07);
    out_datetime->month = bcd_to_dec(data[5] & 0x1F);
    out_datetime->year = bcd_to_dec(data[6]);

    return ESP_OK;
}

esp_err_t pcf85063_set_datetime(i2c_port_num_t port, const pcf85063_datetime_t *datetime)
{
    if (datetime == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t data[7] = {
        dec_to_bcd(datetime->seconds),
        dec_to_bcd(datetime->minutes),
        dec_to_bcd(datetime->hours),
        dec_to_bcd(datetime->day),
        dec_to_bcd(datetime->weekday),
        dec_to_bcd(datetime->month),
        dec_to_bcd(datetime->year),
    };

    return pcf85063_write_reg(port, 0x04, data, sizeof(data));
}
