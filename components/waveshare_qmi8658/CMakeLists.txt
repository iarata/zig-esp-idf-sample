idf_component_register(
    SRCS "waveshare_qmi8658.cpp"
    INCLUDE_DIRS "include"
    REQUIRES SensorLib esp_driver_gpio esp_driver_i2c
)
