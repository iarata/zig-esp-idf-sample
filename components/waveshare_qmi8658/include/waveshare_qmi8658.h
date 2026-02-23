#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/** C-facing sample type so sensor backend details stay internal. */
typedef struct {
    float acc_x;
    float acc_y;
    float acc_z;
    float gyr_x;
    float gyr_y;
    float gyr_z;
    float temperature_c;
    uint32_t timestamp;
} waveshare_qmi8658_sample_t;

/** Creates transport bindings and leaves sensor in a known default config. */
esp_err_t waveshare_qmi8658_init(i2c_port_num_t port,
                                 gpio_num_t sda,
                                 gpio_num_t scl,
                                 uint8_t i2c_address,
                                 uint32_t freq_hz);
/** Reapplies the house default profile after reset or runtime changes. */
esp_err_t waveshare_qmi8658_config_default(void);
/** Exposes data-ready state so callers can avoid reading stale samples. */
bool waveshare_qmi8658_data_ready(void);
/** Reads one normalized sample tuple (accel + gyro + temp + timestamp). */
esp_err_t waveshare_qmi8658_read_sample(waveshare_qmi8658_sample_t *out_sample);

#ifdef __cplusplus
}
#endif
