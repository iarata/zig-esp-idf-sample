#pragma once

#include <stddef.h>
#include <stdint.h>

#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

#define PCF85063_I2C_ADDRESS 0x51

/** Decimal datetime fields so callers never deal with RTC BCD encoding. */
typedef struct {
    uint8_t seconds;
    uint8_t minutes;
    uint8_t hours;
    uint8_t day;
    uint8_t weekday;
    uint8_t month;
    uint8_t year;
} pcf85063_datetime_t;

/** Initializes/reuses bus resources and prepares a PCF85063 device handle. */
esp_err_t pcf85063_init(i2c_port_num_t port, gpio_num_t sda, gpio_num_t scl, uint32_t freq_hz);
/** Low-level register read helper shared by higher-level RTC APIs. */
esp_err_t pcf85063_read_reg(i2c_port_num_t port, uint8_t reg_addr, uint8_t *data, size_t len);
/** Low-level register write helper shared by higher-level RTC APIs. */
esp_err_t pcf85063_write_reg(i2c_port_num_t port, uint8_t reg_addr, const uint8_t *data, size_t len);
/** Reads calendar registers and returns decoded decimal fields. */
esp_err_t pcf85063_get_datetime(i2c_port_num_t port, pcf85063_datetime_t *out_datetime);
/** Encodes decimal fields and writes them into RTC calendar registers. */
esp_err_t pcf85063_set_datetime(i2c_port_num_t port, const pcf85063_datetime_t *datetime);

#ifdef __cplusplus
}
#endif
