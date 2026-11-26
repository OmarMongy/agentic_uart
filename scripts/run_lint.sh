#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs

echo "=== Lint: uart_top (default) ===" | tee logs/lint.log
verilator --lint-only -Wall --top-module uart_top \
  rtl/uart_baud_gen.sv rtl/uart_tx.sv rtl/uart_rx.sv rtl/uart_top.sv \
  2>&1 | tee -a logs/lint.log

echo "=== Lint: uart_top (ENABLE_LOOPBACK=0) ===" | tee -a logs/lint.log
verilator --lint-only -Wall -GENABLE_LOOPBACK=0 --top-module uart_top \
  rtl/uart_baud_gen.sv rtl/uart_tx.sv rtl/uart_rx.sv rtl/uart_top.sv \
  2>&1 | tee -a logs/lint.log

echo "=== Lint: uart_tx standalone ===" | tee -a logs/lint.log
verilator --lint-only -Wall --top-module uart_tx \
  rtl/uart_baud_gen.sv rtl/uart_tx.sv \
  2>&1 | tee -a logs/lint.log

echo "=== Lint: uart_rx standalone ===" | tee -a logs/lint.log
verilator --lint-only -Wall --top-module uart_rx \
  rtl/uart_baud_gen.sv rtl/uart_rx.sv \
  2>&1 | tee -a logs/lint.log
