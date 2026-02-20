# ============================================================================
# Zig Bindings Patcher
# Removes and replaces problematic structs/functions from ESP-IDF bindings
# ============================================================================

message(STATUS "Patching Zig bindings: ${TARGET_FILE}")

# ============================================================================
# Read file content
# ============================================================================
file(READ "${TARGET_FILE}" FILE_CONTENT)

function(remove_marker_block CONTENT_VAR BEGIN_MARK END_MARK)
    set(_content "${${CONTENT_VAR}}")
    string(LENGTH "${END_MARK}" _end_mark_len)
    while(TRUE)
        string(FIND "${_content}" "${BEGIN_MARK}" _begin_idx)
        if(_begin_idx EQUAL -1)
            break()
        endif()

        string(SUBSTRING "${_content}" ${_begin_idx} -1 _tail)
        string(FIND "${_tail}" "${END_MARK}" _end_rel)
        if(_end_rel EQUAL -1)
            message(WARNING "Missing end marker '${END_MARK}' for '${BEGIN_MARK}'")
            break()
        endif()

        math(EXPR _after_end_idx "${_begin_idx} + ${_end_rel} + ${_end_mark_len}")
        string(SUBSTRING "${_content}" 0 ${_begin_idx} _prefix)
        string(SUBSTRING "${_content}" ${_after_end_idx} -1 _suffix)
        string(REGEX REPLACE "^\n+" "" _suffix "${_suffix}")
        set(_content "${_prefix}${_suffix}")
    endwhile()
    set(${CONTENT_VAR} "${_content}" PARENT_SCOPE)
endfunction()

function(remove_pub_const_block CONTENT_VAR SYMBOL)
    set(_content "${${CONTENT_VAR}}")
    set(_needle "pub const ${SYMBOL} =")

    while(TRUE)
        string(FIND "${_content}" "${_needle}" _decl_start)
        if(_decl_start EQUAL -1)
            break()
        endif()

        string(SUBSTRING "${_content}" 0 ${_decl_start} _before_decl)
        string(FIND "${_before_decl}" "\n" _line_start REVERSE)
        if(_line_start EQUAL -1)
            set(_block_start 0)
        else()
            math(EXPR _block_start "${_line_start} + 1")
        endif()

        string(SUBSTRING "${_content}" ${_decl_start} -1 _from_decl)
        string(FIND "${_from_decl}" "\n};" _block_end_rel)
        if(_block_end_rel EQUAL -1)
            message(WARNING "Could not find end of block for symbol '${SYMBOL}'")
            break()
        endif()

        math(EXPR _block_end "${_decl_start} + ${_block_end_rel} + 3")
        string(SUBSTRING "${_content}" 0 ${_block_start} _prefix)
        string(SUBSTRING "${_content}" ${_block_end} -1 _suffix)
        string(REGEX REPLACE "^\n+" "" _suffix "${_suffix}")
        set(_content "${_prefix}${_suffix}")
    endwhile()

    set(${CONTENT_VAR} "${_content}" PARENT_SCOPE)
endfunction()

# ============================================================================
# Determine WiFi support based on target
# ============================================================================
if(CONFIG_IDF_TARGET_ESP32P4 OR CONFIG_IDF_TARGET_ESP32H2 OR CONFIG_IDF_TARGET_ESP32H21 OR CONFIG_IDF_TARGET_ESP32H4)
    set(WIFI_SUPPORTED FALSE)
else()
    set(WIFI_SUPPORTED TRUE)
endif()

# ============================================================================
# Component status (passed from zig-config.cmake)
# ============================================================================
if(NOT DEFINED HAS_LED_STRIP)
    set(HAS_LED_STRIP 0)
endif()
if(NOT DEFINED HAS_ESP_DSP)
    set(HAS_ESP_DSP 0)
endif()

# message(STATUS "Component detection:")
# message(STATUS "  HAS_LED_STRIP: ${HAS_LED_STRIP}")
# message(STATUS "  HAS_ESP_DSP: ${HAS_ESP_DSP}")

# ============================================================================
# Remove problematic definitions
# ============================================================================

# Remove previously appended custom patch blocks so this script is idempotent.
remove_marker_block(FILE_CONTENT "// BEGIN_PATCH:i2c_and_touch_configs" "// END_PATCH:i2c_and_touch_configs")
remove_marker_block(FILE_CONTENT "// BEGIN_PATCH:esp_lcd_panel_configs" "// END_PATCH:esp_lcd_panel_configs")
foreach(PATCHED_SYMBOL IN ITEMS
    i2c_master_bus_config_flags_t
    i2c_master_bus_config_t
    i2c_device_config_flags_t
    i2c_device_config_t
    esp_lcd_touch_levels_t
    esp_lcd_touch_flags_t
    esp_lcd_touch_config_t
    esp_lcd_panel_dev_flags_t
    esp_lcd_panel_dev_config_t
    sh8601_vendor_flags_t
    sh8601_vendor_config_t
    esp_lcd_panel_io_i80_dc_levels_t
    esp_lcd_panel_io_i80_flags_t
    esp_lcd_panel_io_i80_config_t
    esp_lcd_panel_io_i2c_flags_t
    esp_lcd_panel_io_i2c_config_t
    esp_lcd_panel_io_spi_flags_t
    esp_lcd_panel_io_spi_config_t
)
    remove_pub_const_block(FILE_CONTENT "${PATCHED_SYMBOL}")
endforeach()

# WiFi patches (only for WiFi-enabled targets)
if(WIFI_SUPPORTED)
    string(REGEX REPLACE "pub const wifi_sta_config_t[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")
    string(REGEX REPLACE "pub const wifi_ap_config_t[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")
endif()

# Remove portTICK_PERIOD_MS (will be replaced with custom version)
string(REGEX REPLACE "pub const portTICK_PERIOD_MS[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")

# Remove I2C and touch config structs that contain demoted opaque bitfields
# and re-add them as explicit packed flag fields via patch snippets.
string(REGEX REPLACE "[^\n]*esp_driver_i2c/include/driver/i2c_master.h:53:18: warning: struct demoted to opaque type - has bitfield\n" "" FILE_CONTENT "${FILE_CONTENT}")

# ESP32-P4 specific: Remove xPortCanYield function
if(CONFIG_IDF_TARGET_ESP32P4)
    string(REGEX REPLACE "pub fn xPortCanYield\\([^)]*\\) callconv\\(\\.c\\) bool \\{([^{}]|\\{[^{}]*\\})*\\}" "" FILE_CONTENT "${FILE_CONTENT}")
endif()

# LED Strip component patches (if enabled)
if(HAS_LED_STRIP EQUAL 1)
    message(STATUS "  Applying LED Strip patches")
    string(REGEX REPLACE "pub const struct_led_strip_rmt_extra_config_20[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")
    string(REGEX REPLACE "pub const struct_format_layout_15[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")
    string(REGEX REPLACE "pub const led_strip_rmt_config_t[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")
    string(REGEX REPLACE "pub const led_color_component_format_t[^;]*;" "" FILE_CONTENT "${FILE_CONTENT}")
    string(REGEX REPLACE "pub const led_strip_config_t = extern struct \\{[^}]*\\};" "" FILE_CONTENT "${FILE_CONTENT}")
endif()

# ============================================================================
# Append custom patch files
# ============================================================================
get_filename_component(PATCH_DIR "${CMAKE_CURRENT_LIST_DIR}/../patches" ABSOLUTE)

# Define patches to apply
set(PATCH_FILES
    "porttick_period_ms.zig"
    "i2c_and_touch_configs.zig"
    "esp_lcd_panel_configs.zig"
)

# Add target-specific patches
if(CONFIG_IDF_TARGET_ESP32P4)
    list(APPEND PATCH_FILES "xport_can_yield.zig")
endif()

# Add WiFi patches
if(WIFI_SUPPORTED)
    list(APPEND PATCH_FILES
        "wifi_sta_config_t.zig"
        "wifi_ap_config_t.zig"
    )
endif()

# Add LED Strip patches
if(HAS_LED_STRIP EQUAL 1)
    list(APPEND PATCH_FILES
        "led_strip_rmt_extra_config_20.zig"
        "led_strip_struct_format_layout_15.zig"
        "led_color_component_format_t.zig"
        "led_strip_rmt_config_t.zig"
        "led_strip_config_t.zig"
    )
endif()

# Apply each patch file
foreach(PATCH_FILE IN LISTS PATCH_FILES)
    set(PATCH_PATH "${PATCH_DIR}/${PATCH_FILE}")
    if(EXISTS "${PATCH_PATH}")
        message(STATUS "  Applying patch: ${PATCH_FILE}")
        file(READ "${PATCH_PATH}" PATCH_CONTENT)
        string(APPEND FILE_CONTENT "\n${PATCH_CONTENT}")
    else()
        message(WARNING "  Patch file not found: ${PATCH_FILE}")
    endif()
endforeach()

# ============================================================================
# Write patched content
# ============================================================================
file(WRITE "${TARGET_FILE}" "${FILE_CONTENT}")
message(STATUS "Patching completed: ${TARGET_FILE}")
