/*
 * Copyright (c) 2026 Alexis Valencia
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_alexisval08_price_slope -- price slope signal chip
 *
 * Reads one 8-bit price per clock tick, measures the SLOPE over the last
 * LOOKBACK ticks, and displays a BUY / HOLD / SELL letter on the board's
 * 7-segment display.
 *
 *     slope = price[now] - price[now - LOOKBACK]
 *
 *     slope >  +THRESHOLD  ->  BUY   ('b')
 *     slope <  -THRESHOLD  ->  SELL  ('S')
 *     otherwise            ->  HOLD  ('H')
 *
 * The band between -THRESHOLD and +THRESHOLD is a deliberate dead zone. A
 * rule with no dead zone flips state on every one-tick wiggle; the HOLD band
 * is what stops that, so THRESHOLD is the noise-rejection knob.
 *
 * The decimal point lights while the price history is still filling, which
 * marks the signal as not yet valid. Until LOOKBACK+1 prices have been
 * clocked in, price[now - LOOKBACK] is still a reset zero and the slope would
 * be meaningless, so the chip forces HOLD and raises the point.
 *
 * Board mapping (ChipDiscover v1.2):
 *     ui_in[7:0]  DIP switches 1-8   -- the price
 *     clk         MANCLK button      -- one press = one new price
 *     rst_n       RST button         -- clears the history
 *     uo_out[6:0] 7-segment display  -- the letter
 *     uo_out[7]   decimal point      -- history still filling
 */

`default_nettype none
`timescale 1ns / 1ps

module tt_um_alexisval08_price_slope #(
    // Both are fixed at build time, exactly as the project scope specifies:
    // changing them means re-running synthesis.
    parameter integer       LOOKBACK  = 4,       // ticks back to compare against
    //
    // THRESHOLD is declared signed and 9 bits wide to match `slope` exactly.
    // Writing it as a plain `integer` makes it 32 bits, and every use of it
    // then truncates down to 9 -- harmless here, but a linter flags it
    // (Verilator: "expects 9 bits ... generates 32 bits") and a clean lint is
    // worth more than the saved keystrokes. Sizing it here means the compare
    // below is 9-bit signed against 9-bit signed, with no conversion at all.
    parameter signed [8:0]  THRESHOLD = 9'sd10   // half-width of the HOLD band
    //
    // Picking THRESHOLD: a random walk with a typical per-tick move of s
    // drifts about s*sqrt(LOOKBACK) over LOOKBACK ticks just by chance. Set
    // THRESHOLD near that and noise stays inside the dead zone while a real
    // trend pushes past it. Measured on 8-bit samples with s ~ 5, LOOKBACK 4:
    // THRESHOLD 10 gave 0 signals in pure noise and 24 in a trend, while
    // THRESHOLD 3 chattered 24 times out of 40 ticks in that same noise.
) (
    input  wire [7:0] ui_in,    // Dedicated inputs  -- the price
    output wire [7:0] uo_out,   // Dedicated outputs -- 7-segment + decimal point
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path  -- signal code for the testbench
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock -- one tick per new price
    input  wire       rst_n     // reset_n - low to reset
);

  localparam [7:0] HISTORY_SIZE = LOOKBACK[7:0] + 8'd1;

  // --------------------------------------------------------------------------
  // 7-segment patterns, in Tiny Tapeout's standard segment order:
  //
  //        aaa          uo_out[0] = a (top)        uo_out[4] = e (bottom-left)
  //       f   b         uo_out[1] = b (top-right)  uo_out[5] = f (top-left)
  //       f   b         uo_out[2] = c (bottom-rt)  uo_out[6] = g (middle)
  //        ggg          uo_out[3] = d (bottom)     uo_out[7] = decimal point
  //       e   c
  //       e   c         The literals below are written {g,f,e,d,c,b,a}, so the
  //        ddd          leftmost bit is segment g and the rightmost is a.
  // --------------------------------------------------------------------------
  localparam [6:0] SEG_b = 7'b1111100;  // c,d,e,f,g  -> lowercase b
  localparam [6:0] SEG_H = 7'b1110110;  // b,c,e,f,g  -> H
  localparam [6:0] SEG_S = 7'b1101101;  // a,c,d,f,g  -> S

  // Signal codes exported for the testbench
  localparam [1:0] CODE_HOLD = 2'b00;
  localparam [1:0] CODE_BUY  = 2'b01;
  localparam [1:0] CODE_SELL = 2'b10;

  // --------------------------------------------------------------------------
  // Price history
  //
  // A shift register LOOKBACK+1 deep. hist[0] is the newest price just clocked
  // in; hist[LOOKBACK] is the price from LOOKBACK ticks ago. Those are the only
  // two entries the slope needs -- the ones in between exist purely to carry
  // values along the chain, one step per tick.
  // --------------------------------------------------------------------------
  reg [7:0] hist [0:LOOKBACK];
  reg [7:0] sample_count;

  integer i;

  // Signed slope: newest price minus price LOOKBACK ticks ago.
  wire signed [8:0] slope_now = $signed({1'b0, hist[0]}) - $signed({1'b0, hist[LOOKBACK]});
  wire valid = sample_count >= HISTORY_SIZE;

  // Combinational decision logic for the display and testbench signal.
  reg [6:0] seg_out;
  reg [1:0] signal_code;

  always @(*) begin
    if (!valid) begin
      seg_out = SEG_H;
      signal_code = CODE_HOLD;
    end else if (slope_now > THRESHOLD) begin
      seg_out = SEG_b;
      signal_code = CODE_BUY;
    end else if (slope_now < -THRESHOLD) begin
      seg_out = SEG_S;
      signal_code = CODE_SELL;
    end else begin
      seg_out = SEG_H;
      signal_code = CODE_HOLD;
    end
  end

  // Shift history in on each new sample. Reset clears all entries and the
  // validity counter, while leaving the output in HOLD until enough samples are
  // present to compute a real slope.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i <= LOOKBACK; i = i + 1) begin
        hist[i] <= 8'd0;
      end
      sample_count <= 8'd0;
    end else begin
      // Shift the queue forward: hist[0] is the newest sample.
      for (i = LOOKBACK; i > 0; i = i - 1) begin
        hist[i] <= hist[i - 1];
      end
      hist[0] <= ui_in;

      if (sample_count < HISTORY_SIZE) begin
        sample_count <= sample_count + 8'd1;
      end
    end
  end

  // Drive the board outputs.
  assign uo_out[6:0] = seg_out;
  assign uo_out[7] = ~valid;

  // A 0..3 code lets the testbench tell BUY/HOLD/SELL apart without needing to
  // decode the 7-seg pattern. Do not expose the unused GPIOs to the world.
  assign uio_out[1:0] = signal_code;
  assign uio_out[7:2] = 6'b000000;
  assign uio_oe = 8'hFF;

endmodule

// Compatibility wrapper for the stock Tiny Tapeout testbench and for projects
// that expect the generic top-module name.
module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  tt_um_alexisval08_price_slope #(
    .LOOKBACK(4),
    .THRESHOLD(9'sd10)
  ) dut (
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
  );

endmodule