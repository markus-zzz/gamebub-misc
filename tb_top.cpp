#include "Vtop.h"
#include "verilated.h"
#include "verilated_fst_c.h"
#include <gtk/gtk.h>

class FrameDumper {
public:
  FrameDumper(Vtop &top) : mTop(top) {
    m_FramePixBuf =
        gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, c_Xres, c_Yres);
    gdk_pixbuf_fill(m_FramePixBuf, 0);
  }
  void tick() {
    if (!mPrev_lcd_dotclk && mTop.lcd_dotclk) {

      bool FrameDone = false;

      if (!mPrev_lcd_hsync && mTop.lcd_hsync) {
        m_HCntr = 0;
        m_VCntr++;
      }
      mPrev_lcd_hsync = mTop.lcd_hsync;

      if (!mPrev_lcd_vsync && mTop.lcd_vsync) {
        m_VCntr = 0;
        FrameDone = true;
      }
      mPrev_lcd_vsync = mTop.lcd_vsync;

      unsigned m_HCntrShifted = m_HCntr - 55;
      unsigned m_VCntrShifted = m_VCntr - 15;
      if (0 <= m_HCntrShifted && m_HCntrShifted < c_Xres &&
          0 <= m_VCntrShifted && m_VCntrShifted < c_Yres) {
        guchar Red = ((mTop.lcd_db >> 0) & 0x3f) << 2;
        guchar Green = ((mTop.lcd_db >> 6) & 0x3f) << 2;
        guchar Blue = ((mTop.lcd_db >> 12) & 0x3f) << 2;
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
    mPrev_lcd_dotclk = mTop.lcd_dotclk;
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
  Vtop &mTop;
};

class SpiWrite {
public:
  SpiWrite(Vtop &top, uint32_t addr, uint32_t data)
      : mTop(top), mAddr(addr), mData(data) {}
  bool tick() {
    switch (mState) {
    case State::PRE_CS_HI:
    case State::PRE_CS_LO:
      // Do nothing
      break;
    case State::CMD:
    case State::ADDR:
    case State::DUMMY:
    case State::DATA:
      mTop.mcu_spi_clk = !mTop.mcu_spi_clk;
      if (mTop.mcu_spi_clk)
        return false;
      break;
    case State::POST_CS_LO:
    case State::POST_CS_HI:
      // Do nothing
      break;
    }

    switch (mState) {
    case State::PRE_CS_HI:
      mTop.mcu_spi_cs_n = 1;
      if (mCntr == 1) {
        mState = State::PRE_CS_LO;
        mCntr = 0;
      }
      break;
    case State::PRE_CS_LO:
      mTop.mcu_spi_cs_n = 0;
      if (mCntr == 1) {
        mState = State::CMD;
        mCntr = 0;
      }
      break;
    case State::CMD:
      mTop.mcu_spi_mosi = (mCmd & 0x8000) ? 1 : 0;
      mCmd <<= 1;
      if (mCntr == 16) {
        mState = State::ADDR;
        mCntr = 0;
      }
      break;
    case State::ADDR:
      mTop.mcu_spi_mosi = (mAddr & 0x8000'0000) ? 1 : 0;
      mAddr <<= 1;
      if (mCntr == 32) {
        mState = State::DUMMY;
        mCntr = 0;
      }
      break;
    case State::DUMMY:
      mTop.mcu_spi_mosi = 0;
      if (mCntr == 8) {
        mState = State::DATA;
        mCntr = 0;
      }
      break;
    case State::DATA:
      mTop.mcu_spi_mosi = (mData & 0x8000'0000) ? 1 : 0;
      mData <<= 1;
      if (mCntr == 32 + 1) { // XXX: Why +1?
        mState = State::POST_CS_LO;
        mCntr = 0;
      }
      break;
    case State::POST_CS_LO:
      mTop.mcu_spi_cs_n = 0;
      if (mCntr == 1) {
        mState = State::POST_CS_HI;
        mCntr = 0;
      }
      break;
    case State::POST_CS_HI:
      mTop.mcu_spi_cs_n = 1;
      if (mCntr == 1) {
        return true;
      }
      break;
    }
    mCntr++;

    return false;
  }

private:
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
  Vtop &mTop;
  uint16_t mCmd = 0x8000; // Write
  uint32_t mAddr;
  uint32_t mData;
};

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  Vtop *top = new Vtop;

  // Create FST trace object
  VerilatedFstC *tfp = new VerilatedFstC;
  top->trace(tfp, 99);
  tfp->open("dump.fst");

  top->clk_50mhz = 0;
  // top->rst = 1;
  top->mcu_spi_clk = 1;

  FrameDumper frame(*top);
  SpiWrite spi(*top, 0xf800'1010, 0xcafe'c0fe);

  for (int i = 0; i < 50000000; ++i) {
    top->clk_50mhz = !top->clk_50mhz;
    frame.tick();
    if ((i % 4) == 0 && top->clk_50mhz)
      spi.tick();
    top->eval();
    tfp->dump(i);
  }

  tfp->close();
  delete tfp;
  delete top;
  return 0;
}
