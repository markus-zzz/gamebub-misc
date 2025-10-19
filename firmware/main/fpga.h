#pragma once

#define BASE_ILA 0xf8100000
#define BASE_ILA_RAM 0xf8100000
#define R_RESET_CTRL 0xf8000000
#define R_ILA_INFO 0xf8180000
#define R_ILA_CTRL_STATUS 0xf8180004
#define BASE_SCRATCH_RAM 0xf8200000

#define SDCARD_FPGA_AR "/sdcard/fpga.ar"
#define SDCARD_FPGA_BIT "/sdcard/fpga.bit"
#define SDCARD_ILA_SIG "/sdcard/ila.sig"

uint32_t fpga_user_read_u32(uint32_t addr);
void fpga_user_write_u32(uint32_t addr, uint32_t data);

void fpga_program_path(const char *bitpath);

void ila_parse_signals(const char *sig_path);
