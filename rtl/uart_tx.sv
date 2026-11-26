// Parameterizable 8N1 UART Transmitter.
// Accepts parallel bytes via valid/ready handshake and serializes LSB-first.
module uart_tx #(
  parameter int unsigned CLK_FREQ   = 50_000_000,
  parameter int unsigned BAUD_RATE  = 115_200,
  parameter int unsigned OVERSAMPLE = 16
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [7:0] tx_data,
  input  logic       tx_valid,
  output logic       tx_ready,
  output logic       tx_serial
);

  localparam logic [63:0] CLK_FREQ_U    = 64'(CLK_FREQ);
  localparam logic [63:0] TARGET_FREQ_U = 64'(BAUD_RATE) * 64'(OVERSAMPLE);

  generate
    if ((OVERSAMPLE < 4) || ((OVERSAMPLE % 2) != 0)) begin : gen_err_oversample
      $error("uart_tx: OVERSAMPLE must be an even integer >= 4 (got %0d)", OVERSAMPLE);
    end
    if (TARGET_FREQ_U > CLK_FREQ_U) begin : gen_err_ratio
      $error("uart_tx: BAUD_RATE * OVERSAMPLE (%0d) exceeds CLK_FREQ (%0d)",
             TARGET_FREQ_U, CLK_FREQ_U);
    end
  endgenerate

  typedef enum logic [1:0] {
    TX_IDLE  = 2'd0,
    TX_START = 2'd1,
    TX_DATA  = 2'd2,
    TX_STOP  = 2'd3
  } tx_state_t;

  tx_state_t  tx_state;
  logic [7:0] tx_shift_reg;
  logic [2:0] tx_bit_idx;

  logic       tx_accept;
  logic       tx_busy;
  logic       tx_bit_tick;

  assign tx_accept = (tx_state == TX_IDLE) && tx_valid && tx_ready;
  assign tx_busy   = (tx_state != TX_IDLE);

  // Per-frame phase-aligned 1x bit-period timing enable
  uart_baud_gen #(
    .CLK_FREQ   (CLK_FREQ),
    .BAUD_RATE  (BAUD_RATE),
    .OVERSAMPLE (1)
  ) u_tx_baud_gen (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (tx_busy),
    .clr   (tx_accept),
    .tick  (tx_bit_tick)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state     <= TX_IDLE;
      tx_shift_reg <= 8'h00;
      tx_bit_idx   <= 3'd0;
      tx_ready     <= 1'b0;
      tx_serial    <= 1'b1;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          tx_serial <= 1'b1;
          if (tx_valid && tx_ready) begin
            tx_shift_reg <= tx_data;
            tx_bit_idx   <= 3'd0;
            tx_ready     <= 1'b0;
            tx_serial    <= 1'b0;
            tx_state     <= TX_START;
          end else begin
            tx_ready <= 1'b1;
          end
        end

        TX_START: begin
          tx_ready <= 1'b0;
          if (tx_bit_tick) begin
            tx_serial  <= tx_shift_reg[0];
            tx_bit_idx <= 3'd0;
            tx_state   <= TX_DATA;
          end
        end

        TX_DATA: begin
          tx_ready <= 1'b0;
          if (tx_bit_tick) begin
            if (tx_bit_idx == 3'd7) begin
              tx_serial <= 1'b1;
              tx_state  <= TX_STOP;
            end else begin
              tx_serial    <= tx_shift_reg[1];
              tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
              tx_bit_idx   <= tx_bit_idx + 3'd1;
            end
          end
        end

        TX_STOP: begin
          tx_serial <= 1'b1;
          if (tx_bit_tick) begin
            tx_ready <= 1'b1;
            tx_state <= TX_IDLE;
          end else begin
            tx_ready <= 1'b0;
          end
        end

        default: begin
          tx_state     <= TX_IDLE;
          tx_shift_reg <= 8'h00;
          tx_bit_idx   <= 3'd0;
          tx_ready     <= 1'b0;
          tx_serial    <= 1'b1;
        end
      endcase
    end
  end

endmodule
