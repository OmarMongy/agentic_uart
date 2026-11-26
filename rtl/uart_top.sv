// Top-level UART integrating TX, RX, and selectable internal loopback self-test.
module uart_top #(
  parameter int unsigned CLK_FREQ        = 50_000_000,
  parameter int unsigned BAUD_RATE       = 115_200,
  parameter int unsigned OVERSAMPLE      = 16,
  parameter int unsigned ENABLE_LOOPBACK = 1
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       loopback_en,
  input  logic [7:0] tx_data,
  input  logic       tx_valid,
  output logic       tx_ready,
  output logic       tx_serial,
  input  logic       rx_serial_in,
  output logic [7:0] rx_data,
  output logic       rx_valid,
  output logic       framing_error
);

  generate
    if ((ENABLE_LOOPBACK != 0) && (ENABLE_LOOPBACK != 1)) begin : gen_err_loopback
      $error("uart_top: ENABLE_LOOPBACK must be 0 or 1 (got %0d)", ENABLE_LOOPBACK);
    end
  endgenerate

  logic rx_serial_mux;

  generate
    if (ENABLE_LOOPBACK == 1) begin : gen_loopback_mux
      assign rx_serial_mux = loopback_en ? tx_serial : rx_serial_in;
    end else begin : gen_no_loopback
      logic _unused_loopback_en;
      assign _unused_loopback_en = &{1'b0, loopback_en};
      assign rx_serial_mux       = rx_serial_in;
    end
  endgenerate

  uart_tx #(
    .CLK_FREQ   (CLK_FREQ),
    .BAUD_RATE  (BAUD_RATE),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_uart_tx (
    .clk       (clk),
    .rst_n     (rst_n),
    .tx_data   (tx_data),
    .tx_valid  (tx_valid),
    .tx_ready  (tx_ready),
    .tx_serial (tx_serial)
  );

  uart_rx #(
    .CLK_FREQ   (CLK_FREQ),
    .BAUD_RATE  (BAUD_RATE),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_uart_rx (
    .clk           (clk),
    .rst_n         (rst_n),
    .rx_serial     (rx_serial_mux),
    .rx_data       (rx_data),
    .rx_valid      (rx_valid),
    .framing_error (framing_error)
  );

endmodule
