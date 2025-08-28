#include "esp_check.h"
#include "esp_event.h"
#include "esp_random.h"
#include <esp_http_server.h>
#include <esp_log.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "fpga.h"
#include "index.html.h"

static const char *TAG = "http";

static uint32_t ila_trig_post = 0;

static esp_err_t get_handler_index(httpd_req_t *req) {
  httpd_resp_send(req, (char *)html_index_html, html_index_html_len);
  return ESP_OK;
}

static const httpd_uri_t uri_index = {.uri = "/",
                                      .method = HTTP_GET,
                                      .handler = get_handler_index,
                                      .user_ctx = NULL};

static esp_err_t get_handler_ila_status(httpd_req_t *req) {
  char buf[128];
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");

  uint32_t status = fpga_user_read_u32(R_ILA_CTRL_STATUS);
  int running = status & 0x1;
  int triggered = (status >> 1) & 0x1;

  int res = snprintf(buf, sizeof(buf), "{\n\"running\": %d,\n\"triggered\": %d\n}\n", running, triggered);
  httpd_resp_send(req, buf, res);
  return ESP_OK;
}
static const httpd_uri_t uri_ila_status = {.uri = "/ila_status",
                                        .method = HTTP_GET,
                                        .handler = get_handler_ila_status,
                                        .user_ctx = NULL};

static esp_err_t get_handler_ila_samples(httpd_req_t *req) {
  char buf[128];
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");

  uint32_t info = fpga_user_read_u32(R_ILA_INFO);
  int width = info & 0xffff;
  int depth = info >> 16;
  uint32_t status = fpga_user_read_u32(R_ILA_CTRL_STATUS);
  int running = status & 0x1;
  int triggered = (status >> 1) & 0x1;
  uint32_t trig_idx = status >> 8;

  printf("R_ILA_CTRL_INFO: width=%d depth=%d\n", width, depth);
  printf("R_ILA_CTRL_STATUS: running=%d triggered=%d trig_idx=0x%lx\n", running, triggered, trig_idx);

  int res = snprintf(buf, sizeof(buf), "{\n\"trigger_pos\": %lu,\n\"samples\": [\n", depth - ila_trig_post);
  httpd_resp_send_chunk(req, buf, res);

  unsigned idx = trig_idx + ila_trig_post;
  for (int i = 0; i < depth; i++) {
    uint32_t sample = fpga_user_read_u32(BASE_ILA_RAM + (idx++ % depth) * 4);
    res = snprintf(buf, sizeof(buf), "%lu%s\n", sample, i == depth - 1 ? "" : ",");
    httpd_resp_send_chunk(req, buf, res);
  }
  res = snprintf(buf, sizeof(buf), "]\n}\n");
  httpd_resp_send_chunk(req, buf, res);
  httpd_resp_send_chunk(req, NULL, 0);

  return ESP_OK;
}

static const httpd_uri_t uri_ila_samples = {.uri = "/ila_samples",
                                        .method = HTTP_GET,
                                        .handler = get_handler_ila_samples,
                                        .user_ctx = NULL};

static esp_err_t get_handler_ila_arm(httpd_req_t *req) {
  printf("Client pressed 'Arm' button\n");
  // Setup and arm ILA
  uint32_t info = fpga_user_read_u32(R_ILA_INFO);
  int depth = info >> 16;
  ila_trig_post = depth >> 1; // 50% trig pos
  fpga_user_write_u32(R_ILA_CTRL_STATUS, (ila_trig_post << 8) | 1); // post_trig, running=1
  httpd_resp_send(req, NULL, 0);
  return ESP_OK;
}
static const httpd_uri_t uri_ila_arm = {.uri = "/ila_arm",
                                        .method = HTTP_GET,
                                        .handler = get_handler_ila_arm,
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
    httpd_register_uri_handler(server, &uri_ila_status);
    httpd_register_uri_handler(server, &uri_ila_arm);
    httpd_register_uri_handler(server, &uri_ila_samples);
  } else {
    ESP_LOGI(TAG, "Error starting server!");
  }
}
