import time
import machine

class LCD:
    def __init__(self) -> None:
        self._spi = machine.SPI(2, baudrate=10_000_000, sck=machine.Pin(4), mosi=machine.Pin(5))
        self._pin_rst = machine.Pin(1, machine.Pin.OUT)
        self._pin_cs = machine.Pin(2, machine.Pin.OUT)
        self._pin_dc = machine.Pin(3, machine.Pin.OUT)
        self._pin_backlight = machine.Pin(42, machine.Pin.OUT)
        self._pwm_backlight = machine.PWM(self._pin_backlight, freq=30_000, duty=256)

    def set_backlight(self, intensity) -> None:
        self._pwm_backlight.duty(int(intensity * 256))

    def _write_cmd(self, cmd: int, params: bytes = bytes()) -> None:
        self._pin_cs.value(0)
        self._pin_dc.value(0) # command
        self._spi.write(bytes([cmd]))
        if params:
            self._pin_cs.value(1) # Is toggling cs necessary?
            self._pin_cs.value(0)
            self._pin_dc.value(1) # data
            self._spi.write(params)
        self._pin_cs.value(1)

    def _write_data(self, bytes) -> None:
        self._pin_cs.value(0)
        self._pin_dc.value(1)
        self._spi.write(bytes)

    def setup(self) -> None:
        self._pin_cs.value(1)
        # Pulse reset
        self._pin_rst.value(0)
        time.sleep_us(100)
        self._pin_rst.value(1)

        # Must wait 120ms to send "SLEEP OUT"
        time.sleep_ms(120)

        # Sleep out
        self._write_cmd(0x11)
        time.sleep_ms(10)

        # Display on
        self._write_cmd(0x29)
        time.sleep_ms(10)

        # Display Inversion ON
        self._write_cmd(0x21)

        # Column inversion mode
        self._write_cmd(0xB4, bytes([0x00]))

        # BYPASS memory, direct to shift register
        self._write_cmd(0xB6, bytes([0xB2, 0x62]))

    def set_pos(self, xs, xe, ys, ye):
        # Column Address Set
        self._write_cmd(0x2A, bytes([xs>>8, xs&0xff, xe>>8, xe&0xff]))
        # Page Address Set
        self._write_cmd(0x2B, bytes([ys>>8, ys&0xff, ye>>8, ye&0xff]))
        # Begin Memory Write
        self._write_cmd(0x2C)

    def selftest(self) -> None:
        rgb = []
        for idx in range(10*10):
            rgb.append(0x00)
            rgb.append(0xff)
            rgb.append(0x00)
        for x in range(100, 200, 20):
            for y in range(100, 200, 20):
                self.set_pos(x, x+9, y, y+9)
                self._write_data(bytes(rgb))
