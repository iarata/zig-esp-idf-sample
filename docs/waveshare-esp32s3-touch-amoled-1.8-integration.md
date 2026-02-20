# ESP32-S3-Touch-AMOLED-1.8: Extracted Components and Zig/ESP-IDF Integration

## 1. Scope

This document describes how the Waveshare ESP32-S3-Touch-AMOLED-1.8 demo components were extracted into this project and wired for Zig + ESP-IDF builds.

It covers:

- Local reusable components now in `components/`
- Managed dependencies in `main/idf_component.yml`
- Build-system integration details (`main/CMakeLists.txt`, `cmake/extra-components.cmake`, `include/stubs.h`)
- ESP-IDF v6 compatibility fixes applied
- Verification procedure and results for `esp32s3`
- Zig usage notes and C ABI entry points

Verification in this document was run on **2026-02-20**.

## 2. Environment Activation (`idf.py` access)

Per your environment, `idf.py` is available after activating IDF v6.0-beta2.

Use:

```sh
source /Users/arata/.espressif/tools/activate_idf_v6.0-beta2.sh
export PATH="/opt/homebrew/bin:$IDF_PATH/tools:$PATH"
```

Then `idf.py` commands work as expected.

Notes:

- If your shell already has `cmake` on `PATH`, the extra `/opt/homebrew/bin` prepend may be unnecessary.
- In this workspace, adding `/opt/homebrew/bin` was required to avoid `"cmake" must be available on the PATH`.
- If you switch between host and devcontainer, regenerate `dependencies.lock` to avoid stale absolute local paths:
  - `rm -f dependencies.lock`
  - `rm -rf managed_components build-verify`
  - rerun `idf.py -B build-verify set-target esp32s3`

## 3. Extracted Local Components

The following components are now local under `components/`.

### 3.1 Power / Sensors / RTC

- `components/XPowersLib`
  - Source: Waveshare `01_AXP2101`
  - Role: PMU library backend for AXP2101

- `components/SensorLib`
  - Source: Waveshare `03_QMI8658`
  - Role: sensor backend used by QMI8658 wrapper

- `components/waveshare_axp2101`
  - New C ABI wrapper around `XPowersLib`
  - Header: `components/waveshare_axp2101/include/waveshare_axp2101.h`

- `components/waveshare_qmi8658`
  - New C ABI wrapper around `SensorLib` QMI8658 flow
  - Header: `components/waveshare_qmi8658/include/waveshare_qmi8658.h`

- `components/pcf85063`
  - C driver extracted for RTC use
  - Header: `components/pcf85063/include/pcf85063.h`

### 3.2 Display / Touch

- `components/esp_lcd_sh8601`
  - Source: Waveshare LVGL demo display driver
  - Header: `components/esp_lcd_sh8601/include/esp_lcd_sh8601.h`

- `components/esp_lcd_touch`
  - Source: Waveshare touch core component
  - Header: `components/esp_lcd_touch/include/esp_lcd_touch.h`

- `components/esp_lcd_touch_ft5x06`
  - Source: Waveshare touch controller driver (FT5x06 family, used for FT3168 in this board stack)
  - Header: `components/esp_lcd_touch_ft5x06/include/esp_lcd_touch_ft5x06.h`

## 4. Managed Dependencies (`idf_component.yml`)

`main/idf_component.yml` includes:

```yaml
dependencies:
  idf:
    version: ">=5.0.4"
  espressif/esp_io_expander_tca9554: "^1.0.1"
  espressif/es8311: "^1.0.0"
  espressif/esp_lvgl_port: "^2.7.1"
  lvgl/lvgl: "^9.5.0"
```

Resolved (from `dependencies.lock` during verification):

- `espressif/es8311` = `1.0.0`
- `espressif/esp_io_expander` = `1.2.0` (transitive)
- `espressif/esp_io_expander_tca9554` = `1.0.1`
- `espressif/esp_lvgl_port` = `2.7.1`
- `lvgl/lvgl` = `9.5.0`
- `idf` = `6.0.0`

## 5. Build Integration in This Repo

### 5.1 Main component requirements

`main/CMakeLists.txt` now requires local + managed components:

- `waveshare_axp2101`
- `waveshare_qmi8658`
- `pcf85063`
- `esp_lcd_sh8601`
- `esp_lcd_touch`
- `esp_lcd_touch_ft5x06`
- `es8311`
- `esp_io_expander_tca9554`

This ensures headers/symbols are visible to app and Zig binding generation.

### 5.2 Optional include detection for Zig binding generation

`cmake/extra-components.cmake`:

- Detects managed and local components present in the current build.
- Adds include directories dynamically.
- Emits preprocessor flags `HAS_*` (for example `HAS_WAVESHARE_AXP2101=1`).

`include/stubs.h` includes optional headers guarded by these flags, including:

- `waveshare_axp2101.h`
- `waveshare_qmi8658.h`
- `pcf85063.h`
- `esp_lcd_sh8601.h`
- `esp_lcd_touch.h`
- `esp_lcd_touch_ft5x06.h`
- `es8311.h`
- `esp_io_expander.h`
- `esp_io_expander_tca9554.h`

This keeps `zig translate-c` stable even when some components are absent.

## 6. ESP-IDF v6 Compatibility Fixes Applied

The following implementation fixes were applied so the extracted stack builds on ESP-IDF v6.0-beta2:

1. `components/waveshare_axp2101/waveshare_axp2101.cpp`
   - Added `#define XPOWERS_CHIP_AXP2101` before including `XPowersLib.h`.
   - Ensures `XPowersPMU` is defined for AXP2101.

2. `components/esp_lcd_sh8601/include/esp_lcd_sh8601.h`
   - Added fallback defines for:
     - `ESP_LCD_SH8601_VER_MAJOR`
     - `ESP_LCD_SH8601_VER_MINOR`
     - `ESP_LCD_SH8601_VER_PATCH`
   - Prevents compile errors in version log path.

3. GPIO dependency updates for IDF 6 split driver components:
   - `components/esp_lcd_touch/CMakeLists.txt`
   - `components/esp_lcd_touch_ft5x06/CMakeLists.txt`
   - `components/esp_lcd_sh8601/CMakeLists.txt`
   - `managed_components/espressif__es8311/CMakeLists.txt`
   
   Added `esp_driver_gpio` requirement where `driver/gpio.h` is included.

4. Touch API compatibility shim for `esp_lvgl_port` 2.7.1:
   - `components/esp_lcd_touch/include/esp_lcd_touch.h`
   - `components/esp_lcd_touch/esp_lcd_touch.c`
   
   Added:
   - `esp_lcd_touch_point_data_t`
   - `esp_lcd_touch_get_data(...)`
   
   This bridges newer `esp_lvgl_port` expectations to the extracted touch core API.

5. Previous integration fixes retained:
   - `cmake/extra-components.cmake`: local include loop corrected (`foreach(COMP_SUBDIR ${ARGN})`)
   - `cmake/zig-config.cmake`:
     - includes `${IDF_PATH}/components/esp_lcd/include`
     - uses `${CMAKE_BINARY_DIR}/config` first (correct for custom build dirs)
   - `components/SensorLib/src/SensorCommon.tpp`:
     - explicit cast from `int` to `gpio_num_t` for stricter toolchains

## 7. Public C APIs for Zig (`@cImport`)

### 7.1 AXP2101

Header: `components/waveshare_axp2101/include/waveshare_axp2101.h`

- `waveshare_axp2101_init(...)`
- `waveshare_axp2101_apply_touch_amoled_1_8_defaults()`
- `waveshare_axp2101_read_status(...)`

### 7.2 QMI8658

Header: `components/waveshare_qmi8658/include/waveshare_qmi8658.h`

- `waveshare_qmi8658_init(...)`
- `waveshare_qmi8658_config_default()`
- `waveshare_qmi8658_data_ready()`
- `waveshare_qmi8658_read_sample(...)`

### 7.3 PCF85063

Header: `components/pcf85063/include/pcf85063.h`

- `pcf85063_init(...)`
- `pcf85063_read_reg(...)`
- `pcf85063_write_reg(...)`
- `pcf85063_get_datetime(...)`
- `pcf85063_set_datetime(...)`

### 7.4 Display / Touch

- `esp_lcd_sh8601.h` for SH8601 panel integration
- `esp_lcd_touch.h` and `esp_lcd_touch_ft5x06.h` for FT3168/FT5x06 family touch path

## 8. Typical Board Pin Reference (from demo code)

The Waveshare LVGL demo (`demos/05_LVGL_WITH_RAM/main/example_qspi_with_ram.c`) uses:

- QSPI LCD:
  - CS: GPIO12
  - PCLK: GPIO11
  - D0..D3: GPIO4, GPIO5, GPIO6, GPIO7
- Touch I2C:
  - SDA: GPIO15
  - SCL: GPIO14
  - INT: GPIO21
- Touch I2C host: `I2C_NUM_0`

RTC/QMI/AXP demos also commonly use `I2C_NUM_0` with SDA 15 / SCL 14 in this board family.

Always confirm against your exact hardware revision.

## 9. Verification Procedure and Result

### 9.1 Commands used

```sh
source /Users/arata/.espressif/tools/activate_idf_v6.0-beta2.sh
export PATH="/opt/homebrew/bin:$IDF_PATH/tools:$PATH"

idf.py -B build-verify set-target esp32s3
idf.py -B build-verify build
```

### 9.2 Result (2026-02-20)

Verification build completed successfully for `esp32s3`.

Generated artifacts include:

- `build-verify/bootloader/bootloader.bin`
- `build-verify/zig-sample-idf.bin`

Final size report from build:

- `zig-sample-idf.bin` size: `0x3bb10`
- app partition size: `0x100000`
- free space: `0xc44f0` (77%)

## 10. Known Warnings / Forward Work

1. Legacy I2C API warning on ESP-IDF v6
   - Current extracted/demo code relies on `driver/i2c.h` (legacy API).
   - ESP-IDF warns this driver is EOL and planned for removal in v7.0.
   - Future hardening task: migrate these components to `driver/i2c_master.h` / `driver/i2c_slave.h`.

2. `es8311` source compatibility patch
   - `managed_components/espressif__es8311/CMakeLists.txt` was adjusted to require `esp_driver_gpio`.
   - If `managed_components` is regenerated from scratch, this local patch may need to be reapplied unless upstream updates.

## 11. Minimal Zig Usage Example

```zig
const c = @cImport({
    @cInclude("waveshare_axp2101.h");
    @cInclude("waveshare_qmi8658.h");
    @cInclude("pcf85063.h");
    @cInclude("esp_lcd_sh8601.h");
    @cInclude("esp_lcd_touch_ft5x06.h");
});

pub fn initPeripherals() void {
    _ = c.waveshare_axp2101_init(c.I2C_NUM_0, @intCast(15), @intCast(14), 400_000);
    _ = c.waveshare_axp2101_apply_touch_amoled_1_8_defaults();
}
```

The generated Zig IDF bindings (`imports/idf-sys.zig`) will expose these symbols when the corresponding components are part of the build.
