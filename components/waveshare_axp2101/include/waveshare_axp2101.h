#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Stable C snapshot type so callers don't depend on XPowersLib classes. */
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

/** Brings up PMU I2C access and enables telemetry channels. */
esp_err_t waveshare_axp2101_init(i2c_port_num_t port, gpio_num_t sda, gpio_num_t scl, uint32_t freq_hz);
/** Applies the known-good rail profile for Waveshare Touch AMOLED 1.8 boards. */
esp_err_t waveshare_axp2101_apply_touch_amoled_1_8_defaults(void);
/** Returns one PMU telemetry snapshot without mutating PMU configuration. */
esp_err_t waveshare_axp2101_read_status(waveshare_axp2101_status_t *out_status);

#ifdef __cplusplus
}
#endif
