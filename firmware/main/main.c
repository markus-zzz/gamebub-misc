#include "driver/gpio.h"
#include "driver/sdmmc_host.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_vfs_fat.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "sdmmc_cmd.h"
#include <string.h>

#include "lwip/err.h"
#include "lwip/sys.h"

#include "fpga.h"

/* FreeRTOS event group to signal when we are connected*/
static EventGroupHandle_t s_wifi_event_group;

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

#define GPIO_STATUS_LED GPIO_NUM_36

static const char *TAG = "wifi station";

static int s_retry_num = 0;

static esp_netif_ip_info_t ip_info;

static void event_handler(void *arg, esp_event_base_t event_base,
                          int32_t event_id, void *event_data) {
  if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
    esp_wifi_connect();
  } else if (event_base == WIFI_EVENT &&
             event_id == WIFI_EVENT_STA_DISCONNECTED) {
    if (s_retry_num < CONFIG_ESP_MAXIMUM_RETRY) {
      esp_wifi_connect();
      s_retry_num++;
      ESP_LOGI(TAG, "retry to connect to the AP");
    } else {
      xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
    }
    ESP_LOGI(TAG, "connect to the AP fail");
  } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
    ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
    ESP_LOGI(TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
    ip_info = event->ip_info;
    s_retry_num = 0;
    xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
  }
}

void wifi_init_sta(void) {
  s_wifi_event_group = xEventGroupCreate();

  ESP_ERROR_CHECK(esp_netif_init());

  ESP_ERROR_CHECK(esp_event_loop_create_default());
  esp_netif_create_default_wifi_sta();

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  esp_event_handler_instance_t instance_any_id;
  esp_event_handler_instance_t instance_got_ip;
  ESP_ERROR_CHECK(esp_event_handler_instance_register(
      WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL, &instance_any_id));
  ESP_ERROR_CHECK(esp_event_handler_instance_register(
      IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL, &instance_got_ip));

  wifi_config_t wifi_config = {
      .sta =
          {
              .ssid = CONFIG_ESP_WIFI_SSID,
              .password = CONFIG_ESP_WIFI_PASSWORD,
              .threshold.authmode = WIFI_AUTH_WPA2_PSK,
              .sae_pwe_h2e = WPA3_SAE_PWE_BOTH,
              .sae_h2e_identifier = "",
          },
  };
  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
  ESP_ERROR_CHECK(esp_wifi_start());

  ESP_LOGI(TAG, "wifi_init_sta finished.");

  EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
                                         WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                                         pdFALSE, pdFALSE, portMAX_DELAY);

  if (bits & WIFI_CONNECTED_BIT) {
    ESP_LOGI(TAG, "connected to ap SSID:%s password:%s", CONFIG_ESP_WIFI_SSID,
             CONFIG_ESP_WIFI_PASSWORD);
  } else if (bits & WIFI_FAIL_BIT) {
    ESP_LOGI(TAG, "Failed to connect to SSID:%s, password:%s",
             CONFIG_ESP_WIFI_SSID, CONFIG_ESP_WIFI_PASSWORD);
  } else {
    ESP_LOGE(TAG, "UNEXPECTED EVENT");
  }
}

void setup_sdcard() {
  esp_err_t ret;

  esp_vfs_fat_sdmmc_mount_config_t mount_config = {
      .format_if_mount_failed = true,
      .max_files = 5,
      .allocation_unit_size = 16 * 1024};
  sdmmc_card_t *card;
  sdmmc_host_t host = SDMMC_HOST_DEFAULT();

  sdmmc_slot_config_t slot_config = SDMMC_SLOT_CONFIG_DEFAULT();

  slot_config.width = 4;
  slot_config.clk = 33;
  slot_config.cmd = 47;
  slot_config.d0 = 34;
  slot_config.d1 = 48;
  slot_config.d2 = 21;
  slot_config.d3 = 26;
  slot_config.flags |= SDMMC_SLOT_FLAG_INTERNAL_PULLUP;

  ESP_LOGI(TAG, "Mounting filesystem");
  ret = esp_vfs_fat_sdmmc_mount("/sdcard", &host, &slot_config, &mount_config,
                                &card);

  if (ret != ESP_OK) {
    if (ret == ESP_FAIL) {
      ESP_LOGE(TAG, "Failed to mount filesystem. "
                    "If you want the card to be formatted, set the "
                    "EXAMPLE_FORMAT_IF_MOUNT_FAILED menuconfig option.");
    } else {
      ESP_LOGE(TAG,
               "Failed to initialize the card (%s). "
               "Make sure SD card lines have pull-up resistors in place.",
               esp_err_to_name(ret));
    }
    return;
  }
  ESP_LOGI(TAG, "Filesystem mounted");

  // Card has been initialized, print its properties
  sdmmc_card_print_info(stdout, card);

  FILE *fp = fopen("/sdcard/index.html", "r");
  if (fp) {
    int ch;
    while ((ch = fgetc(fp)) != EOF) {
      putchar(ch);
    }
    fclose(fp);
  }
}

#define CHARSET2_OFF 2048
extern const unsigned char font[];

void ovl_char(unsigned x, unsigned y, char chr) {
  if (islower(chr))
    chr = chr - 'a' + 1;
  x = 19 - x;
  for (unsigned i = 0; i < 8; i++) {
    uint32_t addr = 0xf8300000 + 20 * (i + y * 8) + (x >> 2) * 4;
    uint32_t mask = 0xffUL << (8 * (x & 3));
    uint32_t dword = fpga_user_read_u32(addr) & ~mask;
    dword |= font[CHARSET2_OFF + (unsigned)chr * 8 + i] << (8 * (x & 3));
    fpga_user_write_u32(addr, dword);
    // printf("ovl_char: addr=0x%08lx dword=0x%08lx\n", addr, dword);
  }
}

void ovl_printf(unsigned x, unsigned y, const char *format, ...) {
#define MAX_OVL_WIDTH 20
  char buffer[MAX_OVL_WIDTH + 1];
  va_list args;
  va_start(args, format);
  vsnprintf(buffer, sizeof(buffer), format, args);
  va_end(args);

  for (unsigned i = 0; buffer[i] != '\0' && i + x < MAX_OVL_WIDTH; i++) {
    ovl_char(x + i, y, buffer[i]);
  }
}

void lcd_init();
void fpga_init();
void start_webserver();
void fpga_start_program_service();

void app_main(void) {

  // Turn off status LED as it is too bright
  gpio_config_t io_conf = {};
  io_conf.intr_type = GPIO_INTR_DISABLE;
  io_conf.mode = GPIO_MODE_OUTPUT;
  io_conf.pin_bit_mask = 1ULL << GPIO_STATUS_LED;
  io_conf.pull_down_en = 0;
  io_conf.pull_up_en = 0;
  gpio_config(&io_conf);
  gpio_set_level(GPIO_STATUS_LED, 0);

  // Initialize NVS
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
      ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    ret = nvs_flash_init();
  }
  ESP_ERROR_CHECK(ret);

  if (CONFIG_LOG_MAXIMUM_LEVEL > CONFIG_LOG_DEFAULT_LEVEL) {
    /* If you only want to open more logs in the wifi module, you need to make
     * the max level greater than the default level, and call
     * esp_log_level_set() before esp_wifi_init() to improve the log level of
     * the wifi module. */
    esp_log_level_set("wifi", CONFIG_LOG_MAXIMUM_LEVEL);
  }

  setup_sdcard();

  lcd_init();
  fpga_init();

  const char *sdcard_fpga_bit = "/sdcard/fpga.bit";
  ESP_LOGI(TAG, "Program FPGA from '%s'\n", sdcard_fpga_bit);
  fpga_program_path(sdcard_fpga_bit);

  ESP_LOGI(TAG, "ESP_WIFI_MODE_STA");
  wifi_init_sta();

  unsigned row = 0;
  ovl_printf(0, row++, "Connected to:");
  ovl_printf(1, row++, "ssid: %s", CONFIG_ESP_WIFI_SSID);
  ovl_printf(1, row++, "ip: " IPSTR, IP2STR(&ip_info.ip));
  ovl_printf(1, row++, "nm: " IPSTR, IP2STR(&ip_info.netmask));
  ovl_printf(1, row++, "gw: " IPSTR, IP2STR(&ip_info.gw));

  // Temporary write /sdcard/ila.sig
  // File format is LSB to MSB
  {
    FILE *fp = fopen("/sdcard/ila.sig", "w");
    fputs("foo.hpos 10\n", fp);
    fputs("vpos 10\n", fp);
    fputs("# Ignore this comment\n", fp);
    fputs("btn_right 1\n", fp);
    fclose(fp);
  }

  start_webserver();

  fpga_start_program_service();
}
