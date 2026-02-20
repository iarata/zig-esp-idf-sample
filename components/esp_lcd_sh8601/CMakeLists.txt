idf_component_register(
    SRCS "esp_lcd_sh8601.c"
    INCLUDE_DIRS "include"
    PRIV_REQUIRES "driver" "esp_driver_gpio"
    REQUIRES "esp_lcd"
)
