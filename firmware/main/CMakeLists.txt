idf_component_register(SRCS "main.c" "fpga.c" "lcd.c"
                    PRIV_REQUIRES esp_driver_gpio esp_driver_spi esp_wifi nvs_flash
                    INCLUDE_DIRS ".")
