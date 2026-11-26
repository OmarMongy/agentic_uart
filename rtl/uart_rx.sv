// Parameterizable 8N1 UART Receiver with 2-flop input synchronizer and
// 16x oversampling center-bit validation.
module uart_rx #(
  parameter int unsigned CLK_FREQ   = 50_000_000,
  parameter int unsigned BAUD_RATE  = 115_200,
  parameter int unsigned OVERSAMPLE = 16
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       rx_serial,
  output logic [7:0] rx_data,
  output logic       rx_valid,
  output logic       framing_error
);

  localparam logic [63:0] CLK_FREQ_U    = 64'(CLK_FREQ);
  localparam logic [63:0] TARGET_FREQ_U = 64'(BAUD_RATE) * 64'(OVERSAMPLE);

  generate
    if ((OVERSAMPLE < 4) || ((OVERSAMPLE % 2) != 0)) begin : gen_err_oversample
      $error("uart_rx: OVERSAMPLE must be an even integer >= 4 (got %0d)", OVERSAMPLE);
    end
    if (TARGET_FREQ_U > CLK_FREQ_U) begin : gen_err_ratio
      $error("uart_rx: BAUD_RATE * OVERSAMPLE (%0d) exceeds CLK_FREQ (%0d)",
             TARGET_FREQ_U, CLK_FREQ_U);
    end
  endgenerate

  localparam int SAMPLE_CNT_W   = (OVERSAMPLE <= 2) ? 2 : $clog2(OVERSAMPLE);
  localparam int HALF_BIT_INT   = (OVERSAMPLE / 2) - 1;
  localparam int FULL_BIT_INT   = OVERSAMPLE - 1;

  localparam logic [SAMPLE_CNT_W-1:0] HALF_BIT_TICKS = HALF_BIT_INT[SAMPLE_CNT_W-1:0];
  localparam logic [SAMPLE_CNT_W-1:0] FULL_BIT_TICKS = FULL_BIT_INT[SAMPLE_CNT_W-1:0];

  typedef enum logic [2:0] {
    RX_IDLE      = 3'd0,
    RX_START     = 3'd1,
    RX_DATA      = 3'd2,
    RX_STOP      = 3'd3,
    RX_WAIT_IDLE = 3'd4
  } rx_state_t;

  rx_state_t               rx_state;
  logic [SAMPLE_CNT_W-1:0] sample_cnt;
  logic [2:0]              bit_idx;
  logic [7:0]              rx_shift_reg;

  // Two-flop synchronizer + previous-cycle register for falling-edge detection
  logic rx_sync_ff1;
  logic rx_sync_ff2;
  logic rx_sync_prev;
  logic rx_falling_edge;

  logic rx_tick_16x;

  // Free-running 16x oversampling timing enable
  uart_baud_gen #(
    .CLK_FREQ   (CLK_FREQ),
    .BAUD_RATE  (BAUD_RATE),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_rx_baud_gen (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (1'b1),
    .clr   (1'b0),
    .tick  (rx_tick_16x)
  );

  // Synchronize asynchronous serial input; reset all stages to idle-high (1'b1).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync_ff1  <= 1'b1;
      rx_sync_ff2  <= 1'b1;
      rx_sync_prev <= 1'b1;
    end else begin
      rx_sync_ff1  <= rx_serial;
      rx_sync_ff2  <= rx_sync_ff1;
      rx_sync_prev <= rx_sync_ff2;
    end
  end

  assign rx_falling_edge = rx_sync_prev && !rx_sync_ff2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state      <= RX_IDLE;
      sample_cnt    <= '0;
      bit_idx       <= 3'd0;
      rx_shift_reg  <= 8'h00;
      rx_data       <= 8'h00;
      rx_valid      <= 1'b0;
      framing_error <= 1'b0;
    end else begin
      // Single-cycle status pulses default low every cycle.
      rx_valid      <= 1'b0;
      framing_error <= 1'b0;

      case (rx_state)
        RX_IDLE: begin
          sample_cnt <= '0;
          if (rx_falling_edge) begin
            rx_state <= RX_START;
          end
        end

        RX_START: begin
          if (rx_tick_16x) begin
            if (sample_cnt == HALF_BIT_TICKS) begin
              sample_cnt <= '0;
              if (rx_sync_ff2 == 1'b0) begin
                // Start bit confirmed near center; sample bit 0 after 1 full bit (OVERSAMPLE ticks).
                bit_idx  <= 3'd0;
                rx_state <= RX_DATA;
              end else begin
                // Short low glitch / false start rejected.
                rx_state <= RX_IDLE;
              end
            end else begin
              sample_cnt <= sample_cnt + 1'b1;
            end
          end
        end

        RX_DATA: begin
          if (rx_tick_16x) begin
            if (sample_cnt == FULL_BIT_TICKS) begin
              sample_cnt   <= '0;
              rx_shift_reg <= {rx_sync_ff2, rx_shift_reg[7:1]};
              if (bit_idx == 3'd7) begin
                rx_state <= RX_STOP;
              end else begin
                bit_idx <= bit_idx + 3'd1;
              end
            end else begin
              sample_cnt <= sample_cnt + 1'b1;
            end
          end
        end

        RX_STOP: begin
          if (rx_tick_16x) begin
            if (sample_cnt == FULL_BIT_TICKS) begin
              sample_cnt <= '0;
              if (rx_sync_ff2 == 1'b1) begin
                rx_data  <= rx_shift_reg;
                rx_valid <= 1'b1;
                rx_state <= RX_IDLE;
              end else begin
                // Preserve previous rx_data; wait for line return-to-high before next frame.
                framing_error <= 1'b1;
                rx_state      <= RX_WAIT_IDLE;
              end
            end else begin
              sample_cnt <= sample_cnt + 1'b1;
            end
          end
        end

        RX_WAIT_IDLE: begin
          sample_cnt <= '0;
          if (rx_sync_ff2 == 1'b1) begin
            rx_state <= RX_IDLE;
          end
        end

        default: begin
          rx_state     <= RX_IDLE;
          sample_cnt   <= '0;
          bit_idx      <= 3'd0;
          rx_shift_reg <= 8'h00;
        end
      endcase
    end
  end

endmodule
