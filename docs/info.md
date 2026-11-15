<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The design samples an unsigned 8-bit price from `ui_in` on each rising edge of
`clk`. It keeps the latest five samples and compares the newest sample with the
sample from four clock ticks earlier:

`slope = newest_price - price_from_four_ticks_ago`

- A slope greater than `+10` produces **BUY**.
- A slope less than `-10` produces **SELL**.
- Slopes from `-10` through `+10`, inclusive, produce **HOLD**.

The threshold band avoids changing the signal for small movements. After reset,
the design outputs HOLD and raises `uo_out[7]` while it collects the first five
samples. Once the history is full, `uo_out[7]` goes low and `uo_out[6:0]`
drives the 7-segment pattern for the signal.

`uio_out[1:0]` also encodes the signal for digital monitoring: `00` is HOLD,
`01` is BUY, and `10` is SELL. All `uio` pins are configured as outputs;
`uio_out[7:2]` are held low. `uio_in` is unused.

## How to test

Install Icarus Verilog and the Python packages listed in
[`test/requirements.txt`](../test/requirements.txt). From the repository root,
run:

```sh
cd test
make
```

The Cocotb test checks reset and history warm-up, rising and falling slopes,
and the inclusive threshold boundaries.

## External hardware

The design is intended for the ChipDiscover v1.2 board mapping: the eight
switches provide the price, the MANCLK button clocks each sample, and the RST
button resets the history. The 7-segment output displays the signal and the
decimal point indicates history warm-up.
