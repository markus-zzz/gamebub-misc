#include "Vtop.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <gtk/gtk.h>
#include <iostream>
#include <memory>
#include <vector>

#define R_RESET_CTRL 0xf800'0000

#define BASE_ILA 0xf810'0000
#define R_ILA_INFO 0xf818'0000
#define R_ILA_CTRL_STATUS 0xf818'0004
#define BASE_ILA_RAM 0xf810'0000

std::unique_ptr<Vtop> top;
std::unique_ptr<VerilatedFstC> tfp;

class FrameDumper {
public:
  FrameDumper() {
    m_FramePixBuf =
        gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, c_Xres, c_Yres);
    gdk_pixbuf_fill(m_FramePixBuf, 0);
  }
  void doTick(uint64_t tick) {
    if (!mPrev_lcd_dotclk && top->lcd_dotclk) {

      bool FrameDone = false;

      if (!mPrev_lcd_hsync && top->lcd_hsync) {
        m_HCntr = 0;
        m_VCntr++;
      }
      mPrev_lcd_hsync = top->lcd_hsync;

      if (!mPrev_lcd_vsync && top->lcd_vsync) {
        m_VCntr = 0;
        FrameDone = true;
      }
      mPrev_lcd_vsync = top->lcd_vsync;

      unsigned m_HCntrShifted = m_HCntr - 55;
      unsigned m_VCntrShifted = m_VCntr - 15;
      if (0 <= m_HCntrShifted && m_HCntrShifted < c_Xres &&
          0 <= m_VCntrShifted && m_VCntrShifted < c_Yres) {
        guchar Red = ((top->lcd_db >> 0) & 0x3f) << 2;
        guchar Green = ((top->lcd_db >> 6) & 0x3f) << 2;
        guchar Blue = ((top->lcd_db >> 12) & 0x3f) << 2;
        PutPixel(m_FramePixBuf, m_HCntrShifted, m_VCntrShifted, Red, Green,
                 Blue);
      }

      m_HCntr++;

      if (FrameDone) {
        char buf[32];
        snprintf(buf, sizeof(buf), "lcd-%04d.png", mFrameIndex++);
        gdk_pixbuf_save(m_FramePixBuf, buf, "png", NULL, NULL);
        printf("%s\n", buf);
        gdk_pixbuf_fill(m_FramePixBuf, 0);
      }
    }
    mPrev_lcd_dotclk = top->lcd_dotclk;
  }

private:
  void PutPixel(GdkPixbuf *pixbuf, int x, int y, guchar red, guchar green,
                guchar blue) {
    int width, height, rowstride, n_channels;
    guchar *pixels, *p;

    n_channels = gdk_pixbuf_get_n_channels(pixbuf);

    g_assert(gdk_pixbuf_get_colorspace(pixbuf) == GDK_COLORSPACE_RGB);
    g_assert(gdk_pixbuf_get_bits_per_sample(pixbuf) == 8);
    g_assert(!gdk_pixbuf_get_has_alpha(pixbuf));
    g_assert(n_channels == 3);

    width = gdk_pixbuf_get_width(pixbuf);
    height = gdk_pixbuf_get_height(pixbuf);

    g_assert(x >= 0 && x < width);
    g_assert(y >= 0 && y < height);

    rowstride = gdk_pixbuf_get_rowstride(pixbuf);
    pixels = gdk_pixbuf_get_pixels(pixbuf);

    p = pixels + y * rowstride + x * n_channels;
    p[0] = red;
    p[1] = green;
    p[2] = blue;
  }

  const unsigned c_Xres = 320;
  const unsigned c_Yres = 480;
  GdkPixbuf *m_FramePixBuf;
  unsigned m_HCntr = 0;
  unsigned m_VCntr = 0;
  unsigned mPrev_lcd_dotclk = 0;
  unsigned mPrev_lcd_hsync = 0;
  unsigned mPrev_lcd_vsync = 0;
  unsigned mFrameIndex = 0;
};

class Command {
public:
  Command() {}
  virtual ~Command() {}
  virtual bool doTick(uint64_t tick) = 0;
};

class Wait : public Command {
public:
  Wait(uint64_t untilTick) : mUntilTick(untilTick) {}
  bool doTick(uint64_t tick) override { return tick >= mUntilTick; }

private:
  uint64_t mUntilTick;
};

class Spi : public Command {
protected:
  Spi() {}
  bool doTick(uint64_t tick) override {
    if (!top->clk_50mhz)
      return false;

    switch (mState) {
    case State::PRE_CS_HI:
      top->mcu_spi_clk = 1;
      break;
    case State::PRE_CS_LO:
      // Do nothing
      break;
    case State::CMD:
    case State::ADDR:
    case State::DUMMY:
    case State::DATA:
      top->mcu_spi_clk = !top->mcu_spi_clk;
      if (top->mcu_spi_clk)
        return false;
      break;
    case State::POST_CS_LO:
    case State::POST_CS_HI:
      // Do nothing
      break;
    }

    switch (mState) {
    case State::PRE_CS_HI:
      top->mcu_spi_cs_n = 1;
      if (mCntr == 1) {
        mState = State::PRE_CS_LO;
        mCntr = 0;
      }
      break;
    case State::PRE_CS_LO:
      top->mcu_spi_cs_n = 0;
      if (mCntr == 1) {
        mState = State::CMD;
        mCntr = 0;
      }
      break;
    case State::CMD:
      top->mcu_spi_mosi = (mCmd & 0x8000) ? 1 : 0;
      mCmd <<= 1;
      if (mCntr == 16) {
        mState = State::ADDR;
        mCntr = 0;
      }
      break;
    case State::ADDR:
      top->mcu_spi_mosi = (mAddr & 0x8000'0000) ? 1 : 0;
      mAddr <<= 1;
      if (mCntr == 32) {
        mState = State::DUMMY;
        mCntr = 0;
      }
      break;
    case State::DUMMY:
      top->mcu_spi_mosi = 0;
      if (mCntr == 8) {
        mState = State::DATA;
        mDataIn = 0;
        mCntr = 0;
      }
      break;
    case State::DATA:
      top->mcu_spi_mosi = (mDataOut & 0x8000'0000) ? 1 : 0;
      mDataOut <<= 1;
      mDataIn = (mDataIn << 1) | (top->mcu_spi_miso & 1);
      if (mCntr == 32 + 1) { // XXX: Why +1?
        mState = State::POST_CS_LO;
        mCntr = 0;
      }
      break;
    case State::POST_CS_LO:
      top->mcu_spi_cs_n = 0;
      if (mCntr == 1) {
        mState = State::POST_CS_HI;
        mCntr = 0;
      }
      break;
    case State::POST_CS_HI:
      top->mcu_spi_cs_n = 1;
      if (mCntr == 1) {
        return true;
      }
      break;
    }
    mCntr++;

    return false;
  }

  enum class State {
    PRE_CS_HI,
    PRE_CS_LO,
    CMD,
    ADDR,
    DUMMY,
    DATA,
    POST_CS_LO,
    POST_CS_HI
  } mState = State::PRE_CS_HI;
  unsigned mCntr = 0;
  uint16_t mCmd = 0x8000; // Write
  uint32_t mAddr;
  uint32_t mDataIn;
  uint32_t mDataOut;
};

class SpiRead : public Spi {
public:
  SpiRead(uint32_t addr, uint32_t &data) {
    mCmd = 0x0000; // Read command
    mAddr = addr;
    mDataOut = data;
  }
  bool doTick(uint64_t tick) override {
    auto res = Spi::doTick(tick);
    if (res)
      std::cout << "SpiRead:  data=" << std::hex << (mDataIn << 1) << "\n";
    return res;
  }
};

class SpiWrite : public Spi {
public:
  SpiWrite(uint32_t addr, uint32_t data) {
    mCmd = 0x8000; // Write command
    mAddr = addr;
    mDataOut = data;
  }
};

void runSim(const std::vector<std::unique_ptr<Command>> &commands) {
  Verilated::traceEverOn(true);

  top = std::make_unique<Vtop>();
  tfp = std::make_unique<VerilatedFstC>();

  top->trace(tfp.get(), 99);
  tfp->open("dump.fst");

  top->clk_50mhz = 0;

  FrameDumper frame;

  uint64_t tick = 0;
  for (auto cmd = commands.begin(); cmd != commands.end();) {
    top->clk_50mhz = !top->clk_50mhz;
    frame.doTick(tick);
    if (cmd != commands.end() && (*cmd)->doTick(tick)) {
      cmd++;
    }
    top->eval();
    tfp->dump(tick);
    tick++;
  }

  tfp->close();
  tfp.reset();
  top.reset();
}

template <class T, class... Args>
void addCmd(std::vector<std::unique_ptr<Command>> &cmds, Args &&...args) {
  cmds.push_back(std::make_unique<T>(std::forward<Args>(args)...));
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  std::vector<std::unique_ptr<Command>> cmds;

  uint32_t readData;

  addCmd<SpiWrite>(cmds, R_RESET_CTRL, 1);          // reset=1
  addCmd<SpiWrite>(cmds, R_RESET_CTRL, 0);          // reset=0
  addCmd<SpiWrite>(cmds, 0xf800'1010, 0xcafe'c0fe); // Set border color
  addCmd<SpiWrite>(cmds, R_ILA_CTRL_STATUS,
                   512 << 8 | 1);          // ILA post_trig=512 running=1
  addCmd<SpiWrite>(cmds, 0x0, 0xcafec0fe); // ILA magic trigger word
  addCmd<Wait>(cmds, 5'000'000);
  addCmd<SpiRead>(cmds, R_ILA_CTRL_STATUS, readData);
  for (unsigned i = 0; i < 8; i++) {
    addCmd<SpiRead>(cmds, BASE_ILA_RAM + i * sizeof(uint32_t), readData);
  }
  addCmd<Wait>(cmds, 5'005'000);
  runSim(cmds);

  return 0;
}
