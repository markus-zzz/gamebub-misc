#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"

#define PIN_LCD_RST 1
#define PIN_LCD_BACKLIGHT 42
#define PIN_LCD_SPI_CS 2
#define PIN_LCD_SPI_DC 3
#define PIN_LCD_SPI_SCLK 4
#define PIN_LCD_SPI_MOSI 5

#define LCD_SPI_BUS SPI3_HOST

static spi_device_handle_t lcd_spi;

static void lcd_write_cmd(uint8_t cmd, unsigned data_len, uint8_t *data) {
  gpio_set_level(PIN_LCD_SPI_CS, 0);
  gpio_set_level(PIN_LCD_SPI_DC, 0); // Command

  spi_transaction_t txn = {};
  txn.length = 8;
  txn.tx_buffer = &cmd;
  esp_err_t ret = spi_device_polling_transmit(lcd_spi, &txn); // Transmit!
  assert(ret == ESP_OK);
  if (data_len > 0) {
    gpio_set_level(PIN_LCD_SPI_CS, 1);
    gpio_set_level(PIN_LCD_SPI_CS, 0);
    gpio_set_level(PIN_LCD_SPI_DC, 1); // Data
    txn.length = 8 * data_len;
    txn.tx_buffer = data;
    esp_err_t ret = spi_device_polling_transmit(lcd_spi, &txn); // Transmit!
    assert(ret == ESP_OK);
  }
  gpio_set_level(PIN_LCD_SPI_CS, 1);
}

#define CONF_GPIO(pin_, mode_)                                                 \
  do {                                                                         \
    gpio_config_t io_conf = {};                                                \
    io_conf.intr_type = GPIO_INTR_DISABLE;                                     \
    io_conf.mode = mode_;                                                      \
    io_conf.pin_bit_mask = 1ULL << pin_;                                       \
    io_conf.pull_down_en = 0;                                                  \
    io_conf.pull_up_en = 0;                                                    \
    gpio_config(&io_conf);                                                     \
  } while (0)

void lcd_init() {
  // Configure GPIO modes and SPI
  CONF_GPIO(PIN_LCD_RST, GPIO_MODE_OUTPUT);
  CONF_GPIO(PIN_LCD_BACKLIGHT, GPIO_MODE_OUTPUT);
  CONF_GPIO(PIN_LCD_SPI_CS, GPIO_MODE_OUTPUT);
  CONF_GPIO(PIN_LCD_SPI_DC, GPIO_MODE_OUTPUT);

  esp_err_t ret;
  spi_bus_config_t buscfg = {.miso_io_num = -1,
                             .mosi_io_num = PIN_LCD_SPI_MOSI,
                             .sclk_io_num = PIN_LCD_SPI_SCLK,
                             .quadwp_io_num = -1,
                             .quadhd_io_num = -1,
                             .max_transfer_sz = 16};

  spi_device_interface_config_t devcfg = {
      .clock_speed_hz = 80 * 1000 * 1000,
      .mode = 0,
      .spics_io_num = -1, // PIN_LCD_SPI_CS,
      .queue_size = 4,
      .pre_cb = NULL,
  };

  // Initialize the dedicated LCD SPI bus
  ret = spi_bus_initialize(LCD_SPI_BUS, &buscfg, SPI_DMA_CH_AUTO);
  ESP_ERROR_CHECK(ret);

  // Attach the LCD to its SPI bus
  ret = spi_bus_add_device(LCD_SPI_BUS, &devcfg, &lcd_spi);
  ESP_ERROR_CHECK(ret);

  // Initialize the ILI9488 LCD
  gpio_set_level(PIN_LCD_BACKLIGHT, 1); // XXX: Should be PWM

  // Pulse LCD reset for 1ms
  gpio_set_level(PIN_LCD_RST, 0);
  vTaskDelay(1 / portTICK_PERIOD_MS); // XXX: 100us should be enough
  gpio_set_level(PIN_LCD_RST, 1);

  // Must wait 120ms to send "SLEEP OUT"
  vTaskDelay(120 / portTICK_PERIOD_MS);

  // Sleep out
  lcd_write_cmd(0x11, 0, NULL);
  vTaskDelay(10 / portTICK_PERIOD_MS);

  // Display on
  lcd_write_cmd(0x29, 0, NULL);
  vTaskDelay(10 / portTICK_PERIOD_MS);

  // Display Inversion ON
  lcd_write_cmd(0x21, 0, NULL);

  // Column inversion mode
  uint8_t arg0[] = {0x00};
  lcd_write_cmd(0xB4, 1, arg0);

  // BYPASS memory, direct to shift register
  uint8_t arg1[] = {0xB2, 0x62};
  lcd_write_cmd(0xB6, 2, arg1);
}
