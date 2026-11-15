# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert (int(dut.uo_out.value) >> 7) & 1 == 1
    assert int(dut.uio_out.value) & 0b11 == 0b00
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1


async def apply_prices(dut, prices):
    for index, price in enumerate(prices):
        if index:
            await FallingEdge(dut.clk)
        dut.ui_in.value = price
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        if index < 4:
            assert (int(dut.uo_out.value) >> 7) & 1 == 1
            assert int(dut.uio_out.value) & 0b11 == 0b00

    assert (int(dut.uo_out.value) >> 7) & 1 == 0


@cocotb.test()
async def test_slope_signal(dut):
    dut.ena.value = 1
    dut.uio_in.value = 0
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    await reset(dut)
    await apply_prices(dut, [20, 30, 35, 45, 60])
    assert int(dut.uio_out.value) & 0b11 == 0b01  # +40: BUY

    await reset(dut)
    await apply_prices(dut, [100, 90, 80, 70, 80])
    assert int(dut.uio_out.value) & 0b11 == 0b10  # -20: SELL

    await reset(dut)
    await apply_prices(dut, [20, 30, 35, 45, 30])
    assert int(dut.uio_out.value) & 0b11 == 0b00  # +10: HOLD at threshold

    await reset(dut)
    await apply_prices(dut, [100, 90, 80, 70, 90])
    assert int(dut.uio_out.value) & 0b11 == 0b00  # -10: HOLD at threshold
