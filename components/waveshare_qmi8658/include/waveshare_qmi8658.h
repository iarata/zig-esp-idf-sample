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
    float acc_x;
    float acc_y;
    float acc_z;
    float gyr_x;
    float gyr_y;
    float gyr_z;
    float temperature_c;
    uint32_t timestamp;
} waveshare_qmi8658_sample_t;

esp_err_t waveshare_qmi8658_init(i2c_port_num_t port,
                                 gpio_num_t sda,
                                 gpio_num_t scl,
                                 uint8_t i2c_address,
                                 uint32_t freq_hz);
esp_err_t waveshare_qmi8658_config_default(void);
bool waveshare_qmi8658_data_ready(void);
esp_err_t waveshare_qmi8658_read_sample(waveshare_qmi8658_sample_t *out_sample);

#ifdef __cplusplus
}
#endif
