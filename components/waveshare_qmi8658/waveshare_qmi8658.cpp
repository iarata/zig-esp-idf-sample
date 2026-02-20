#include "waveshare_qmi8658.h"

#include "SensorQMI8658.hpp"

static SensorQMI8658 s_qmi;
static i2c_port_num_t s_i2c_port = -1;
static i2c_master_bus_handle_t s_i2c_bus = nullptr;
static i2c_master_dev_handle_t s_i2c_dev = nullptr;
static uint8_t s_i2c_address = 0;
static bool s_ready = false;

static int qmi_register_read(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data, uint8_t len)
{
    if (data == nullptr || len == 0 || s_i2c_dev == nullptr || dev_addr != s_i2c_address) {
        return DEV_WIRE_ERR;
    }

    const esp_err_t ret = i2c_master_transmit_receive(
        s_i2c_dev,
        &reg_addr,
        sizeof(reg_addr),
        data,
        len,
        1000);
    return ret == ESP_OK ? DEV_WIRE_NONE : DEV_WIRE_ERR;
}

static int qmi_register_write(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data, uint8_t len)
{
    if (data == nullptr || len == 0 || s_i2c_dev == nullptr || dev_addr != s_i2c_address) {
        return DEV_WIRE_ERR;
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

    const esp_err_t ret = i2c_master_multi_buffer_transmit(
        s_i2c_dev,
        tx_bufs,
        sizeof(tx_bufs) / sizeof(tx_bufs[0]),
        1000);
    return ret == ESP_OK ? DEV_WIRE_NONE : DEV_WIRE_ERR;
}

static esp_err_t ensure_i2c_bus(i2c_port_num_t port,
                                gpio_num_t sda,
                                gpio_num_t scl,
                                uint8_t i2c_address,
                                uint32_t freq_hz)
{
    if (freq_hz == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    if (s_i2c_dev != nullptr) {
        if (s_i2c_port == port && s_i2c_address == i2c_address) {
            return ESP_OK;
        }
        return ESP_ERR_INVALID_STATE;
    }

    esp_err_t err = i2c_master_get_bus_handle(port, &s_i2c_bus);
    if (err == ESP_ERR_INVALID_STATE) {
        i2c_master_bus_config_t bus_cfg = {};
        bus_cfg.i2c_port = port;
        bus_cfg.sda_io_num = sda;
        bus_cfg.scl_io_num = scl;
        bus_cfg.clk_source = I2C_CLK_SRC_DEFAULT;
        bus_cfg.glitch_ignore_cnt = 7;
        bus_cfg.flags.enable_internal_pullup = 1;
        err = i2c_new_master_bus(&bus_cfg, &s_i2c_bus);
    }
    if (err != ESP_OK) {
        return err;
    }

    i2c_device_config_t dev_cfg = {};
    dev_cfg.dev_addr_length = I2C_ADDR_BIT_LEN_7;
    dev_cfg.device_address = i2c_address;
    dev_cfg.scl_speed_hz = freq_hz;
    dev_cfg.scl_wait_us = 0;
    dev_cfg.flags.disable_ack_check = false;
    err = i2c_master_bus_add_device(s_i2c_bus, &dev_cfg, &s_i2c_dev);
    if (err != ESP_OK) {
        s_i2c_bus = nullptr;
        s_i2c_dev = nullptr;
        return err;
    }

    s_i2c_port = port;
    s_i2c_address = i2c_address;
    return ESP_OK;
}

extern "C" esp_err_t waveshare_qmi8658_init(i2c_port_num_t port,
                                            gpio_num_t sda,
                                            gpio_num_t scl,
                                            uint8_t i2c_address,
                                            uint32_t freq_hz)
{
    esp_err_t err = ensure_i2c_bus(port, sda, scl, i2c_address, freq_hz);
    if (err != ESP_OK) {
        return err;
    }

    if (!s_qmi.begin(i2c_address, qmi_register_read, qmi_register_write)) {
        s_ready = false;
        return ESP_FAIL;
    }

    s_ready = true;
    return waveshare_qmi8658_config_default();
}

extern "C" esp_err_t waveshare_qmi8658_config_default(void)
{
    if (!s_ready) {
        return ESP_ERR_INVALID_STATE;
    }

    s_qmi.configAccelerometer(
        SensorQMI8658::ACC_RANGE_4G,
        SensorQMI8658::ACC_ODR_1000Hz,
        SensorQMI8658::LPF_MODE_0,
        true);

    s_qmi.configGyroscope(
        SensorQMI8658::GYR_RANGE_64DPS,
        SensorQMI8658::GYR_ODR_896_8Hz,
        SensorQMI8658::LPF_MODE_3,
        true);

    s_qmi.enableGyroscope();
    s_qmi.enableAccelerometer();

    return ESP_OK;
}

extern "C" bool waveshare_qmi8658_data_ready(void)
{
    if (!s_ready) {
        return false;
    }
    return s_qmi.getDataReady();
}

extern "C" esp_err_t waveshare_qmi8658_read_sample(waveshare_qmi8658_sample_t *out_sample)
{
    if (!s_ready) {
        return ESP_ERR_INVALID_STATE;
    }
    if (out_sample == nullptr) {
        return ESP_ERR_INVALID_ARG;
    }

    if (!s_qmi.getAccelerometer(out_sample->acc_x, out_sample->acc_y, out_sample->acc_z)) {
        return ESP_FAIL;
    }

    if (!s_qmi.getGyroscope(out_sample->gyr_x, out_sample->gyr_y, out_sample->gyr_z)) {
        return ESP_FAIL;
    }

    out_sample->timestamp = s_qmi.getTimestamp();
    out_sample->temperature_c = s_qmi.getTemperature_C();

    return ESP_OK;
}
