idf_component_register(
    SRCS "waveshare_axp2101.cpp"
    INCLUDE_DIRS "include"
    REQUIRES XPowersLib esp_driver_gpio esp_driver_i2c
)
