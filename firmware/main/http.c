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

static esp_err_t get_handler_wildcard(httpd_req_t *req) {
  char buf[1024];
  printf("GET: %s\n", req->uri);

  if (strstr(req->uri, ".json")) {
    httpd_resp_set_type(req, "application/json");
  } else if (strstr(req->uri, ".js")) {
    httpd_resp_set_type(req, "application/javascript");
  } else if (strstr(req->uri, ".wasm")) {
    httpd_resp_set_hdr(req, "Cache-Control", "public, max-age=31536000");
    httpd_resp_set_type(req, "application/wasm");
  }

  snprintf(buf, sizeof(buf), "/sdcard/%s",
           strcmp(req->uri, "/") ? req->uri : "index.html");

  FILE *fp = fopen(buf, "r");
  if (!fp) {
    httpd_resp_send_err(req, HTTPD_404_NOT_FOUND, "File does not exist");
    return ESP_FAIL;
  }
  size_t res;
  while ((res = fread(buf, 1, sizeof(buf), fp))) {
    httpd_resp_send_chunk(req, buf, res);
  }
  // XXX: Should use ferror() to check for error and if so httpd_resp_send_err
  // instead
  httpd_resp_send_chunk(req, NULL, 0);
  fclose(fp);
  return ESP_OK;
}

static const httpd_uri_t uri_wildcard = {.uri = "/*",
                                         .method = HTTP_GET,
                                         .handler = get_handler_wildcard,
                                         .user_ctx = NULL};

static esp_err_t get_handler_ila_status(httpd_req_t *req) {
  char buf[128];
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");

  uint32_t status = fpga_user_read_u32(R_ILA_CTRL_STATUS);
  int running = status & 0x1;
  int triggered = (status >> 1) & 0x1;

  int res =
      snprintf(buf, sizeof(buf), "{\n\"running\": %d,\n\"triggered\": %d\n}\n",
               running, triggered);
  httpd_resp_send(req, buf, res);
  return ESP_OK;
}
static const httpd_uri_t uri_ila_status = {.uri = "/ila_status",
                                           .method = HTTP_GET,
                                           .handler = get_handler_ila_status,
                                           .user_ctx = NULL};

struct ILA_Signal {
  const char *name;
  unsigned bits;
} ila_signals[] = {{
                       .name = "foo",
                       .bits = 5,
                   },
                   {
                       .name = "bar",
                       .bits = 8,
                   }};

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
  printf("R_ILA_CTRL_STATUS: running=%d triggered=%d trig_idx=0x%lx\n", running,
         triggered, trig_idx);

  int res = snprintf(buf, sizeof(buf), "$scope module ILA $end\n");
  httpd_resp_send_chunk(req, buf, res);

  for (unsigned i = 0; i < sizeof(ila_signals) / sizeof(ila_signals[0]); i++) {
    res = snprintf(buf, sizeof(buf), "$var wire %u sig%u %s $end\n",
                   ila_signals[i].bits, i, ila_signals[i].name);
    httpd_resp_send_chunk(req, buf, res);
  }

  res = snprintf(buf, sizeof(buf),
                 "$upscope $end\n$enddefinitions $end\n$dumpvars\n");
  httpd_resp_send_chunk(req, buf, res);

  unsigned idx = trig_idx + ila_trig_post;
  for (int si = 0; si < depth; si++) {
    res = snprintf(buf, sizeof(buf), "#%u\n", si);
    httpd_resp_send_chunk(req, buf, res);

    uint32_t sample = fpga_user_read_u32(BASE_ILA_RAM + (idx++ % depth) * 4);
    for (unsigned i = 0; i < sizeof(ila_signals) / sizeof(ila_signals[0]);
         i++) {
      char *p = &buf[0];
      *p++ = 'b';
      for (unsigned j = 0; j < ila_signals[i].bits; j++) {
        *p++ = (1 << (ila_signals[i].bits - j - 1)) & sample ? '1' : '0';
      }
      res = 1 + ila_signals[i].bits;
      res += snprintf(p, sizeof(buf), " sig%u\n", i);
      httpd_resp_send_chunk(req, buf, res);
      sample >>= ila_signals[i].bits;
    }
  }
  httpd_resp_send_chunk(req, NULL, 0);

  return ESP_OK;
}

static const httpd_uri_t uri_ila_samples = {.uri = "/ila.vcd",
                                            .method = HTTP_GET,
                                            .handler = get_handler_ila_samples,
                                            .user_ctx = NULL};

static esp_err_t get_handler_ila_arm(httpd_req_t *req) {
  printf("Client pressed 'Arm' button\n");
  // Setup and arm ILA
  uint32_t info = fpga_user_read_u32(R_ILA_INFO);
  int depth = info >> 16;
  ila_trig_post = depth >> 1; // 50% trig pos
  fpga_user_write_u32(R_ILA_CTRL_STATUS,
                      (ila_trig_post << 8) | 1); // post_trig, running=1
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
  config.uri_match_fn = httpd_uri_match_wildcard;
  config.lru_purge_enable = true;

  // Start the httpd server
  ESP_LOGI(TAG, "Starting server on port: '%d'", config.server_port);
  if (httpd_start(&server, &config) == ESP_OK) {
    // Set URI handlers
    ESP_LOGI(TAG, "Registering URI handlers");
    httpd_register_uri_handler(server, &uri_ila_status);
    httpd_register_uri_handler(server, &uri_ila_arm);
    httpd_register_uri_handler(server, &uri_ila_samples);
    httpd_register_uri_handler(server, &uri_wildcard);
  } else {
    ESP_LOGI(TAG, "Error starting server!");
  }
}
