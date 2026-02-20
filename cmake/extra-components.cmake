# ─── Optional/Managed Components Detection ───────────────────────────────────
idf_build_get_property(BUILD_COMPS BUILD_COMPONENTS)

# Helper function to check and add component
macro(check_managed_component COMPONENT_NAME VENDOR PACKAGE DEFINE_NAME)
    set(COMP_PATHS "")
    set(COMP_BASE_MANAGED "${CMAKE_SOURCE_DIR}/managed_components/${VENDOR}__${PACKAGE}")
    set(COMP_BASE_LOCAL "${CMAKE_SOURCE_DIR}/components/${PACKAGE}")
    if(EXISTS "${COMP_BASE_MANAGED}")
        set(COMP_BASE "${COMP_BASE_MANAGED}")
    else()
        set(COMP_BASE "${COMP_BASE_LOCAL}")
    endif()

    if("${PACKAGE}" STREQUAL "esp-dsp")
        list(APPEND COMP_PATHS
            "${COMP_BASE}/modules/common/include"
            "${COMP_BASE}/modules/dotprod/include"
            "${COMP_BASE}/modules/support/include"
            "${COMP_BASE}/modules/support/mem/include"
            "${COMP_BASE}/modules/windows/include"
            "${COMP_BASE}/modules/windows/hann/include"
            "${COMP_BASE}/modules/windows/blackman/include"
            "${COMP_BASE}/modules/windows/blackman_harris/include"
            "${COMP_BASE}/modules/windows/blackman_nuttall/include"
            "${COMP_BASE}/modules/windows/nuttall/include"
            "${COMP_BASE}/modules/windows/flat_top/include"
            "${COMP_BASE}/modules/iir/include"
            "${COMP_BASE}/modules/fir/include"
            "${COMP_BASE}/modules/math/include"
            "${COMP_BASE}/modules/math/add/include"
            "${COMP_BASE}/modules/math/sub/include"
            "${COMP_BASE}/modules/math/mul/include"
            "${COMP_BASE}/modules/math/addc/include"
            "${COMP_BASE}/modules/math/mulc/include"
            "${COMP_BASE}/modules/math/sqrt/include"
            "${COMP_BASE}/modules/matrix/include"
            "${COMP_BASE}/modules/matrix/mul/include"
            "${COMP_BASE}/modules/matrix/add/include"
            "${COMP_BASE}/modules/matrix/addc/include"
            "${COMP_BASE}/modules/matrix/mulc/include"
            "${COMP_BASE}/modules/matrix/sub/include"
            "${COMP_BASE}/modules/fft/include"
            "${COMP_BASE}/modules/dct/include"
            "${COMP_BASE}/modules/conv/include"
            "${COMP_BASE}/modules/kalman/ekf/include"
            "${COMP_BASE}/modules/kalman/ekf_imu13states/include"
        )
    else()
        list(APPEND COMP_PATHS "${COMP_BASE}/include")
    endif()

    # Check if component is in build
    if("${VENDOR}__${PACKAGE}" IN_LIST BUILD_COMPS OR "${PACKAGE}" IN_LIST BUILD_COMPS)
        # Verify at least one path exists (check the base directory)
        if(EXISTS "${COMP_BASE}")
            message(STATUS "${COMPONENT_NAME} component found")
            set(${DEFINE_NAME} 1)

            # Add all include paths that actually exist
            set(VALID_PATHS 0)
            foreach(COMP_PATH IN LISTS COMP_PATHS)
                if(EXISTS "${COMP_PATH}")
                    list(APPEND INCLUDE_DIRS "${COMP_PATH}")
                    math(EXPR VALID_PATHS "${VALID_PATHS} + 1")
                endif()
            endforeach()

            if(VALID_PATHS GREATER 0)
                message(STATUS "  Added ${VALID_PATHS} include paths for ${COMPONENT_NAME}")
            else()
                message(WARNING "${COMPONENT_NAME} base exists but no include paths found")
                set(${DEFINE_NAME} 0)
            endif()
        else()
            message(WARNING "${COMPONENT_NAME} in components but not found in managed (${COMP_BASE_MANAGED}) or local (${COMP_BASE_LOCAL})")
            set(${DEFINE_NAME} 0)
        endif()
    else()
        message(STATUS "${COMPONENT_NAME} not in build. To add: idf.py add-dependency ${VENDOR}/${PACKAGE}")
        set(${DEFINE_NAME} 0)
    endif()

    list(APPEND EXTRA_DEFINE_FLAGS "-D${DEFINE_NAME}=${${DEFINE_NAME}}")
endmacro()

macro(check_local_component COMPONENT_NAME COMPONENT_DIR DEFINE_NAME)
    set(COMP_BASE "${CMAKE_SOURCE_DIR}/components/${COMPONENT_DIR}")
    if(EXISTS "${COMP_BASE}")
        message(STATUS "${COMPONENT_NAME} local component found")
        set(${DEFINE_NAME} 1)
        foreach(COMP_SUBDIR ${ARGN})
            set(COMP_PATH "${COMP_BASE}/${COMP_SUBDIR}")
            if(EXISTS "${COMP_PATH}")
                list(APPEND INCLUDE_DIRS "${COMP_PATH}")
            endif()
        endforeach()
    else()
        message(STATUS "${COMPONENT_NAME} local component not found at ${COMP_BASE}")
        set(${DEFINE_NAME} 0)
    endif()

    list(APPEND EXTRA_DEFINE_FLAGS "-D${DEFINE_NAME}=${${DEFINE_NAME}}")
endmacro()

# Add your components here
check_managed_component("LED Strip" "espressif" "led_strip" "HAS_LED_STRIP")
check_managed_component("ESP-DSP" "espressif" "esp-dsp" "HAS_ESP_DSP")
check_managed_component("ES8311" "espressif" "es8311" "HAS_ES8311")
check_managed_component("IO Expander Base" "espressif" "esp_io_expander" "HAS_ESP_IO_EXPANDER")
check_managed_component("IO Expander TCA9554" "espressif" "esp_io_expander_tca9554" "HAS_ESP_IO_EXPANDER_TCA9554")

check_local_component("Waveshare AXP2101 Wrapper" "waveshare_axp2101" "HAS_WAVESHARE_AXP2101" "include")
check_local_component("Waveshare QMI8658 Wrapper" "waveshare_qmi8658" "HAS_WAVESHARE_QMI8658" "include")
check_local_component("PCF85063 Driver" "pcf85063" "HAS_PCF85063" "include")
check_local_component("SH8601 LCD" "esp_lcd_sh8601" "HAS_ESP_LCD_SH8601" "include")
check_local_component("ESP LCD Touch Core" "esp_lcd_touch" "HAS_ESP_LCD_TOUCH" "include")
check_local_component("ESP LCD Touch FT5x06" "esp_lcd_touch_ft5x06" "HAS_ESP_LCD_TOUCH_FT5X06" "include")
