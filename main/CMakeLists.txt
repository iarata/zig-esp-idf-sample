set(DEPS nvs_flash)
if(CONFIG_ESP_WIFI_ENABLED)
    list(APPEND DEPS esp_wifi esp_netif esp_event)
endif()
if(CONFIG_ESP_BT_ENABLED)
    list(APPEND DEPS bt)
endif()
list(APPEND DEPS
    waveshare_axp2101
    waveshare_qmi8658
    pcf85063
    esp_lcd_sh8601
    esp_lcd_touch
    esp_lcd_touch_ft5x06
    es8311
    esp_io_expander_tca9554
)

idf_component_register(
    SRCS "placeholder.c"
    INCLUDE_DIRS "."
    REQUIRES ${DEPS}
)

include(${CMAKE_SOURCE_DIR}/cmake/zig-config.cmake)

# esp-dsp Kalman C++ sources use std::sin/cos/atan and fail on IDF v6 toolchains
# unless <cmath> is available; inject it without patching managed source files.
if(TARGET __idf_espressif__esp-dsp)
    target_compile_options(__idf_espressif__esp-dsp PRIVATE
        $<$<COMPILE_LANGUAGE:CXX>:-includecmath>
    )
endif()
