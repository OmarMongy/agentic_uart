#!/usr/bin/env bash
set -euo pipefail

mkdir -p build logs waveforms

verilator --binary --assert --trace -Wall --timescale 1ns/1ps -Wno-SYNCASYNCNET -j 0 \
  --Mdir build/obj_uart_tb \
  --top-module uart_tb \
  rtl/uart_baud_gen.sv rtl/uart_tx.sv rtl/uart_rx.sv rtl/uart_top.sv \
  sva/uart_sva.sv tb/uart_tb.sv \
  2>&1 | tee logs/sim_compile.log

./build/obj_uart_tb/Vuart_tb 2>&1 | tee logs/sim.log
