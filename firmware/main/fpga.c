#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"

#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>

#define PIN_FPGA_POWER 46
#define PIN_FPGA_DONE 6
#define PIN_FPGA_PROGRAM_B 7
#define PIN_FPGA_INIT_B 8
#define PIN_FPGA_SPI_CS 10

#define PIN_FPGA_SPI_SCLK 12
#define PIN_FPGA_SPI_MOSI 11
#define PIN_FPGA_SPI_MISO 13

#define FPGA_SPI_BUS SPI2_HOST

#define BUF_SIZE 512

uint8_t buf[BUF_SIZE];

static spi_device_handle_t fpga_spi;

static void fpga_program_task(void *arg) {
  int server_fd, client_fd;
  struct sockaddr_in server_addr, client_addr;
  socklen_t client_len = sizeof(client_addr);

  // Create socket
  server_fd = socket(AF_INET, SOCK_STREAM, 0);

  // Prepare server address
  server_addr.sin_family = AF_INET;
  server_addr.sin_addr.s_addr = INADDR_ANY;
  server_addr.sin_port = htons(1234);

  // Bind
  bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr));

  // Listen
  listen(server_fd, 1);

  printf("FPGA Programming Server listening on port %d...\n",
         ntohs(server_addr.sin_port));

  while (1) {
    // Accept
    client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);

    printf("Client connected.\n");

    vTaskDelay(100 / portTICK_PERIOD_MS);
    gpio_set_level(PIN_FPGA_PROGRAM_B, 0);
    vTaskDelay(50 / portTICK_PERIOD_MS);

    printf("init_b (should be 0): %d\n", gpio_get_level(PIN_FPGA_INIT_B));
    gpio_set_level(PIN_FPGA_PROGRAM_B, 1);
    while (gpio_get_level(PIN_FPGA_INIT_B) == 0) {
      printf("waiting for init_b...\n");
      vTaskDelay(50 / portTICK_PERIOD_MS);
    }

    printf("FPGA is in program mode.\n");
    // Discard header
    int discard_bytes = 129;
    while (discard_bytes > 0) {
      int res = recv(client_fd, buf, discard_bytes, 0);
      discard_bytes -= res;
    }

    printf("Programming: ");
    spi_device_acquire_bus(fpga_spi, portMAX_DELAY);
    while (1) {
      int res = recv(client_fd, buf, BUF_SIZE, 0);
      if (res == 0) {
        break;
      }
      spi_transaction_t txn = {};
      txn.length = res * 8;
      txn.tx_buffer = buf;
      txn.flags = SPI_TRANS_CS_KEEP_ACTIVE; // Keep CS active
      esp_err_t ret = spi_device_polling_transmit(fpga_spi, &txn); // Transmit!
      assert(ret == ESP_OK);
      printf("#");
    }
    printf("\n");
    spi_device_release_bus(fpga_spi);

    vTaskDelay(100 / portTICK_PERIOD_MS);
    printf("Done pin (should be 1): %d\n", gpio_get_level(PIN_FPGA_DONE));

    printf("Client disconnected.\n");
    close(client_fd);
  }
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

void fpga_init() {
  // Configure GPIO modes and SPI
  CONF_GPIO(PIN_FPGA_POWER, GPIO_MODE_OUTPUT);
  CONF_GPIO(PIN_FPGA_DONE, GPIO_MODE_INPUT);
  CONF_GPIO(PIN_FPGA_PROGRAM_B, GPIO_MODE_OUTPUT_OD); // open-drain
  CONF_GPIO(PIN_FPGA_INIT_B, GPIO_MODE_INPUT);
  CONF_GPIO(PIN_FPGA_SPI_CS, GPIO_MODE_OUTPUT);

  esp_err_t ret;
  spi_bus_config_t buscfg = {.miso_io_num = PIN_FPGA_SPI_MISO,
                             .mosi_io_num = PIN_FPGA_SPI_MOSI,
                             .sclk_io_num = PIN_FPGA_SPI_SCLK,
                             .quadwp_io_num = -1,
                             .quadhd_io_num = -1,
                             .max_transfer_sz = BUF_SIZE};

  spi_device_interface_config_t devcfg = {
      .clock_speed_hz = 80 * 1000 * 1000,
      .mode = 0,
      .spics_io_num = PIN_FPGA_SPI_CS,
      .queue_size = 4,
      .pre_cb = NULL,
  };

  // Initialize the dedicated FPGA SPI bus
  ret = spi_bus_initialize(FPGA_SPI_BUS, &buscfg, SPI_DMA_CH_AUTO);
  ESP_ERROR_CHECK(ret);

  // Attach the FPGA to its SPI bus
  ret = spi_bus_add_device(FPGA_SPI_BUS, &devcfg, &fpga_spi);
  ESP_ERROR_CHECK(ret);

  // Enable all FPGA power domains
  gpio_set_level(PIN_FPGA_POWER, 1);
}

void fpga_start_program_service() {
  xTaskCreatePinnedToCore(fpga_program_task, "fpga_program_task", 4096, NULL,
                          /*priority=*/3, NULL, /*core=*/0);
}
