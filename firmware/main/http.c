#include "esp_check.h"
#include "esp_event.h"
#include "esp_random.h"
#include <esp_http_server.h>
#include <esp_log.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "index.html.h"

static const char *TAG = "http";

static esp_err_t get_handler_index(httpd_req_t *req) {
  httpd_resp_send(req, (char *)html_index_html, html_index_html_len);
  return ESP_OK;
}

static const httpd_uri_t uri_index = {.uri = "/",
                                      .method = HTTP_GET,
                                      .handler = get_handler_index,
                                      .user_ctx = NULL};

static esp_err_t get_handler_ila_raw(httpd_req_t *req) {
  char buf[128];
  for (int i = 0; i < sizeof(buf); i++) {
    buf[i] = esp_random();
  }
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");
  httpd_resp_send(req, buf, sizeof(buf));
  return ESP_OK;
}

static const httpd_uri_t uri_ila_raw = {.uri = "/ila_raw.bin",
                                        .method = HTTP_GET,
                                        .handler = get_handler_ila_raw,
                                        .user_ctx = NULL};

void start_webserver(void) {
  httpd_handle_t server = NULL;
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.lru_purge_enable = true;

  // Start the httpd server
  ESP_LOGI(TAG, "Starting server on port: '%d'", config.server_port);
  if (httpd_start(&server, &config) == ESP_OK) {
    // Set URI handlers
    ESP_LOGI(TAG, "Registering URI handlers");
    httpd_register_uri_handler(server, &uri_index);
    httpd_register_uri_handler(server, &uri_ila_raw);
  } else {
    ESP_LOGI(TAG, "Error starting server!");
  }
}
