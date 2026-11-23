![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Price Slope Signal

This Tiny Tapeout project compares 8-bit price samples over a four-clock-tick
window and reports a **BUY**, **HOLD**, or **SELL** signal. It is a digital
demonstration of a threshold-based slope detector, not financial advice.

## Operation

On each rising edge of `clk`, the design samples `ui_in[7:0]`. It compares the
newest price with the price from four ticks earlier:

- Slope greater than `+10`: BUY
- Slope less than `-10`: SELL
- Otherwise, including exactly `+10` or `-10`: HOLD

The first five samples fill the history. During that time, the signal remains
HOLD and `uo_out[7]` is high. Afterward, `uo_out[6:0]` drives the 7-segment
letter (`b`, `H`, or `S`) and `uo_out[7]` goes low. `uio_out[1:0]` provides a
binary signal code: `00` HOLD, `01` BUY, `10` SELL.

## Pin use

- `ui_in[7:0]`: unsigned price sample
- `uo_out[6:0]`: 7-segment signal pattern
- `uo_out[7]`: high while history is filling
- `uio_out[1:0]`: binary signal code
- `uio_out[7:2]`: driven low; `uio_in` is unused
- `clk`: sample clock; `rst_n`: active-low reset

The intended ChipDiscover v1.2 mapping uses its switches for the price input,
MANCLK button to clock samples, and RST button to reset.

## Run the simulation

Install Icarus Verilog and the packages in [`test/requirements.txt`](test/requirements.txt), then run:

```sh
cd test
make
```

Project details and the pinout are in [`info.yaml`](info.yaml). See
[`docs/info.md`](docs/info.md) for the datasheet description.
