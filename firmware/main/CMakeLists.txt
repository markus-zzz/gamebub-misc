idf_component_register(SRCS "main.c" "fpga.c" "lcd.c" "http.c"
                    PRIV_REQUIRES esp_driver_gpio esp_driver_spi esp_http_server esp_wifi nvs_flash
                    INCLUDE_DIRS ".")
