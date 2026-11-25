![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Price Slope Signal

**Live simulation:** [Try the chip in Wokwi](https://wokwi.com/projects/481535388184374273),
running the exact Verilog in `src/project.v`.

This Tiny Tapeout design turns a stream of unsigned 8-bit values into a
**BUY**, **HOLD**, or **SELL** trend signal. The values can represent prices,
but the chip does not fetch live market data or place trades; it only processes
the numbers supplied to its input pins.

## How it works

1. **Reset the history.** Pull `rst_n` low to clear the stored samples and
   restart the warm-up period.
2. **Supply samples.** On every rising edge of `clk`, the chip reads the
   current value of `ui_in[7:0]` (0 through 255) and shifts it into its history.
3. **Wait for a full window.** The default lookback is four clock ticks, so the
   chip needs five samples before it can compare the newest sample with the
   sample from four ticks earlier. Until then, it reports HOLD.
4. **Calculate the change.** The slope is the newest value minus the value
   four ticks earlier. With the default threshold of 10:
   - A change greater than `+10` reports **BUY**.
   - A change less than `-10` reports **SELL**.
   - Changes from `-10` through `+10`, including both boundaries, report
     **HOLD**.
5. **Read the result.** The display outputs `b`, `S`, or `H`, and a two-bit
   code independently identifies the result.

For example, after samples `20, 30, 35, 45, 60`, the newest value is `60` and
the value four ticks earlier is `20`. The change is `+40`, so the result is
BUY.

`LOOKBACK` and `THRESHOLD` are Verilog parameters set when the design is built.
The defaults are 4 ticks and 10; changing them requires rebuilding the design.

## Pin connections

| Pins | Purpose |
|---|---|
| `ui_in[7:0]` | Unsigned sample, 0 to 255 |
| `clk` | Samples one new value on each rising edge |
| `rst_n` | Active-low reset; clears history |
| `uo_out[6:0]` | Seven-segment pattern; bit 0 is segment A through bit 6, segment G |
| `uo_out[7]` | High while history is filling; low when the slope is valid |
| `uio_out[1:0]` | `00` HOLD, `01` BUY, `10` SELL |
| `uio_out[7:2]` | Driven low |
| `uio_in` | Unused |

During warm-up the display shows `H`. Once the history is full, it displays
lowercase `b` for BUY, `S` for SELL, or `H` for HOLD. The segment patterns are
defined in `src/project.v`.

The intended ChipDiscover v1.2 demonstration uses the eight switches for
`ui_in`, MANCLK to clock each sample, RST to reset, and the seven-segment
display for `uo_out`. The decimal point follows `uo_out[7]` and indicates
warm-up.

## Run the simulation

Install Icarus Verilog and the Python packages listed in
[`test/requirements.txt`](test/requirements.txt). On Ubuntu:

```sh
sudo apt update
sudo apt install iverilog
python -m pip install -r test/requirements.txt
cd test
make
```

The Cocotb test checks reset and warm-up, BUY and SELL slopes, and HOLD at both
threshold boundaries. Project metadata and pin names are in
[`info.yaml`](info.yaml); the datasheet description is in
[`docs/info.md`](docs/info.md).
