#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    float temperature_c;
    uint16_t battery_mv;
    uint16_t vbus_mv;
    uint16_t system_mv;
    uint8_t battery_percent;
    bool charging;
    bool discharge;
    bool standby;
    bool vbus_in;
    bool vbus_good;
    bool battery_connected;
} waveshare_axp2101_status_t;

esp_err_t waveshare_axp2101_init(i2c_port_num_t port, gpio_num_t sda, gpio_num_t scl, uint32_t freq_hz);
esp_err_t waveshare_axp2101_apply_touch_amoled_1_8_defaults(void);
esp_err_t waveshare_axp2101_read_status(waveshare_axp2101_status_t *out_status);

#ifdef __cplusplus
}
#endif
