#include "waveshare_axp2101.h"

#define XPOWERS_CHIP_AXP2101
#include "XPowersLib.h"

static XPowersPMU s_pmu;
static i2c_port_num_t s_i2c_port = -1;
static i2c_master_bus_handle_t s_i2c_bus = nullptr;
static i2c_master_dev_handle_t s_i2c_dev = nullptr;
static uint8_t s_i2c_address = AXP2101_SLAVE_ADDRESS;
static bool s_initialized = false;

static int pmu_register_read(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data, uint8_t len)
{
    if (data == nullptr || len == 0 || s_i2c_dev == nullptr || dev_addr != s_i2c_address) {
        return -1;
    }

    const esp_err_t ret = i2c_master_transmit_receive(
        s_i2c_dev,
        &reg_addr,
        sizeof(reg_addr),
        data,
        len,
        1000);
    return ret == ESP_OK ? 0 : -1;
}

static int pmu_register_write(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data, uint8_t len)
{
    if (data == nullptr || len == 0 || s_i2c_dev == nullptr || dev_addr != s_i2c_address) {
        return -1;
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
    return ret == ESP_OK ? 0 : -1;
}

static esp_err_t ensure_i2c_bus(i2c_port_num_t port, gpio_num_t sda, gpio_num_t scl, uint32_t freq_hz)
{
    if (freq_hz == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    if (s_i2c_dev != nullptr) {
        return (s_i2c_port == port) ? ESP_OK : ESP_ERR_INVALID_STATE;
    }

    i2c_master_bus_config_t bus_cfg = {};
    bus_cfg.i2c_port = port;
    bus_cfg.sda_io_num = sda;
    bus_cfg.scl_io_num = scl;
    bus_cfg.clk_source = I2C_CLK_SRC_DEFAULT;
    bus_cfg.glitch_ignore_cnt = 7;
    bus_cfg.flags.enable_internal_pullup = 1;

    esp_err_t err = i2c_new_master_bus(&bus_cfg, &s_i2c_bus);
    if (err == ESP_ERR_INVALID_STATE) {
        // The bus is already created by another component; reuse it.
        err = i2c_master_get_bus_handle(port, &s_i2c_bus);
    }
    if (err != ESP_OK) {
        return err;
    }

    i2c_device_config_t dev_cfg = {};
    dev_cfg.dev_addr_length = I2C_ADDR_BIT_LEN_7;
    dev_cfg.device_address = s_i2c_address;
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
    return ESP_OK;
}

extern "C" esp_err_t waveshare_axp2101_init(i2c_port_num_t port, gpio_num_t sda, gpio_num_t scl, uint32_t freq_hz)
{
    esp_err_t err = ensure_i2c_bus(port, sda, scl, freq_hz);
    if (err != ESP_OK) {
        return err;
    }

    if (!s_pmu.begin(AXP2101_SLAVE_ADDRESS, pmu_register_read, pmu_register_write)) {
        return ESP_FAIL;
    }

    s_pmu.clearIrqStatus();
    s_pmu.enableVbusVoltageMeasure();
    s_pmu.enableBattVoltageMeasure();
    s_pmu.enableSystemVoltageMeasure();
    s_pmu.enableTemperatureMeasure();
    s_pmu.disableTSPinMeasure();

    s_initialized = true;
    return ESP_OK;
}

extern "C" esp_err_t waveshare_axp2101_apply_touch_amoled_1_8_defaults(void)
{
    if (!s_initialized) {
        return ESP_ERR_INVALID_STATE;
    }

    s_pmu.disableDC2();
    s_pmu.disableDC3();
    s_pmu.disableDC4();
    s_pmu.disableDC5();

    s_pmu.disableALDO1();
    s_pmu.disableALDO2();
    s_pmu.disableALDO3();
    s_pmu.disableALDO4();
    s_pmu.disableBLDO1();
    s_pmu.disableBLDO2();

    s_pmu.disableCPUSLDO();
    s_pmu.disableDLDO1();
    s_pmu.disableDLDO2();

    s_pmu.setDC3Voltage(3300);
    s_pmu.enableDC3();

    s_pmu.setDC1Voltage(3300);
    s_pmu.enableDC1();

    s_pmu.setALDO1Voltage(1800);
    s_pmu.enableALDO1();

    s_pmu.setALDO2Voltage(2800);
    s_pmu.enableALDO2();

    s_pmu.setALDO4Voltage(3000);
    s_pmu.enableALDO4();

    s_pmu.setALDO3Voltage(3300);
    s_pmu.enableALDO3();

    s_pmu.setBLDO1Voltage(3300);
    s_pmu.enableBLDO1();

    s_pmu.setBLDO2Voltage(3300);
    s_pmu.enableBLDO2();

    s_pmu.disableIRQ(XPOWERS_AXP2101_ALL_IRQ);
    s_pmu.clearIrqStatus();
    s_pmu.enableIRQ(XPOWERS_AXP2101_BAT_INSERT_IRQ |
                    XPOWERS_AXP2101_BAT_REMOVE_IRQ |
                    XPOWERS_AXP2101_VBUS_INSERT_IRQ |
                    XPOWERS_AXP2101_VBUS_REMOVE_IRQ |
                    XPOWERS_AXP2101_PKEY_SHORT_IRQ |
                    XPOWERS_AXP2101_PKEY_LONG_IRQ |
                    XPOWERS_AXP2101_BAT_CHG_DONE_IRQ |
                    XPOWERS_AXP2101_BAT_CHG_START_IRQ);

    s_pmu.setPrechargeCurr(XPOWERS_AXP2101_PRECHARGE_50MA);
    s_pmu.setChargerConstantCurr(XPOWERS_AXP2101_CHG_CUR_200MA);
    s_pmu.setChargerTerminationCurr(XPOWERS_AXP2101_CHG_ITERM_25MA);
    s_pmu.setChargeTargetVoltage(XPOWERS_AXP2101_CHG_VOL_4V1);

    return ESP_OK;
}

extern "C" esp_err_t waveshare_axp2101_read_status(waveshare_axp2101_status_t *out_status)
{
    if (!s_initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (out_status == nullptr) {
        return ESP_ERR_INVALID_ARG;
    }

    out_status->temperature_c = s_pmu.getTemperature();
    out_status->battery_mv = s_pmu.getBattVoltage();
    out_status->vbus_mv = s_pmu.getVbusVoltage();
    out_status->system_mv = s_pmu.getSystemVoltage();
    out_status->charging = s_pmu.isCharging();
    out_status->discharge = s_pmu.isDischarge();
    out_status->standby = s_pmu.isStandby();
    out_status->vbus_in = s_pmu.isVbusIn();
    out_status->vbus_good = s_pmu.isVbusGood();
    out_status->battery_connected = s_pmu.isBatteryConnect();
    out_status->battery_percent = out_status->battery_connected ? s_pmu.getBatteryPercent() : 0;

    return ESP_OK;
}
