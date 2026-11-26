// Protocol-level SystemVerilog Assertions (SVA) and auxiliary reference checker
// for uart_top. Uses black-box external port observations (no RTL FSM assumptions).
module uart_sva #(
  parameter int unsigned CLK_FREQ        = 50_000_000,
  parameter int unsigned BAUD_RATE       = 115_200,
  parameter int unsigned OVERSAMPLE      = 16,
  parameter int unsigned ENABLE_LOOPBACK = 1
) (
  input logic       clk,
  input logic       rst_n,
  input logic       loopback_en,
  input logic [7:0] tx_data,
  input logic       tx_valid,
  input logic       tx_ready,
  input logic       tx_serial,
  input logic       rx_serial_in,
  input logic [7:0] rx_data,
  input logic       rx_valid,
  input logic       framing_error
);

  localparam logic [63:0] CLK_F_64 = 64'(CLK_FREQ);
  localparam logic [63:0] BAUD_64  = 64'(BAUD_RATE);
  localparam logic [63:0] OVS_64   = 64'(OVERSAMPLE);

  localparam int unsigned BIT_CLKS       = int'(CLK_F_64 / BAUD_64);
  localparam int unsigned HALF_BIT_CLKS  = int'(CLK_F_64 / (64'd2 * BAUD_64));
  localparam int unsigned TICK_CLKS      = int'(CLK_F_64 / (BAUD_64 * OVS_64));
  localparam int unsigned FRAME_CLKS_MIN = int'((64'd10 * CLK_F_64) / BAUD_64) - 2;
  localparam int unsigned RX_START_CHK   = HALF_BIT_CLKS - ((TICK_CLKS > 1) ? (TICK_CLKS / 2) : 0);
  localparam int unsigned RX_STOP_CHK    = int'((64'd37 * CLK_F_64) / (64'd4 * BAUD_64));
  localparam int unsigned RX_PULSE_MAX   = ((3 * BIT_CLKS) / 4) + TICK_CLKS + 8;

  function automatic int unsigned bit_center_cyc(input int unsigned b_idx);
    logic [63:0] num;
    begin
      num = (64'(2 * b_idx + 1) * CLK_F_64) / (64'd2 * BAUD_64);
      bit_center_cyc = (num[63:32] != 32'd0) ? 32'hFFFF_FFFF : num[31:0];
    end
  endfunction

  // Guard $past/$stable against invalid pre-reset history.
  logic past_valid;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      past_valid <= 1'b0;
    end else begin
      past_valid <= 1'b1;
    end
  end

  // =========================================================================
  // TX Auxiliary Protocol Monitor
  // =========================================================================
  logic        mon_tx_busy;
  logic        mon_tx_started_once;
  logic [9:0]  mon_tx_exp_frame;
  logic [3:0]  mon_tx_bit_idx;
  int unsigned mon_tx_cyc;
  logic        mon_tx_stop_window;
  logic        mon_tx_bit_mismatch;

  assign mon_tx_stop_window = mon_tx_busy && (mon_tx_cyc >= FRAME_CLKS_MIN);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mon_tx_busy         <= 1'b0;
      mon_tx_started_once <= 1'b0;
      mon_tx_exp_frame    <= 10'h3FF;
      mon_tx_bit_idx      <= 4'd0;
      mon_tx_cyc          <= 0;
      mon_tx_bit_mismatch <= 1'b0;
    end else begin
      mon_tx_bit_mismatch <= 1'b0;

      if (tx_valid && tx_ready) begin
        mon_tx_busy         <= 1'b1;
        mon_tx_started_once <= 1'b1;
        mon_tx_exp_frame    <= {1'b1, tx_data, 1'b0};
        mon_tx_bit_idx      <= 4'd0;
        mon_tx_cyc          <= 0;
      end else if (mon_tx_busy) begin
        if (tx_ready) begin
          mon_tx_busy <= 1'b0;
          mon_tx_cyc  <= 0;
        end else begin
          if ((mon_tx_bit_idx <= 4'd9) && (mon_tx_cyc == bit_center_cyc(int'(mon_tx_bit_idx)))) begin
            if (tx_serial !== mon_tx_exp_frame[mon_tx_bit_idx]) begin
              mon_tx_bit_mismatch <= 1'b1;
            end
            mon_tx_bit_idx <= mon_tx_bit_idx + 4'd1;
          end
          mon_tx_cyc <= mon_tx_cyc + 1;
        end
      end
    end
  end

  // Spec 6.1.1: TX idle level must be high.
  property p_tx_idle_high;
    @(posedge clk) disable iff (!rst_n)
    (past_valid && (!mon_tx_busy || tx_ready)) |-> (tx_serial == 1'b1);
  endproperty
  a_tx_idle_high: assert property (p_tx_idle_high)
    else $error("SVA FAIL [TX-IDLE]: tx_serial low while TX idle at %0t", $time);

  // Spec 6.1.2: tx_ready must deassert after acceptance edge.
  property p_tx_accept_deasserts_ready;
    @(posedge clk) disable iff (!rst_n)
    (tx_valid && tx_ready) |=> !tx_ready;
  endproperty
  a_tx_accept_deasserts_ready: assert property (p_tx_accept_deasserts_ready)
    else $error("SVA FAIL [TX-ACCEPT]: tx_ready did not deassert after handshake at %0t", $time);

  // Spec 6.1.3: tx_ready must remain low throughout active frame.
  property p_tx_busy_hold_ready;
    @(posedge clk) disable iff (!rst_n)
    (mon_tx_busy && !mon_tx_stop_window) |-> !tx_ready;
  endproperty
  a_tx_busy_hold_ready: assert property (p_tx_busy_hold_ready)
    else $error("SVA FAIL [TX-BUSY]: tx_ready asserted before frame completion at %0t", $time);

  // Spec 6.1.4: tx_ready may return high only after stop bit completes.
  property p_tx_completion_ready;
    @(posedge clk) disable iff (!rst_n)
    (past_valid && $rose(tx_ready) && mon_tx_started_once) |-> $past(mon_tx_stop_window);
  endproperty
  a_tx_completion_ready: assert property (p_tx_completion_ready)
    else $error("SVA FAIL [TX-COMPLETE]: tx_ready rose prematurely at %0t", $time);

  // Spec 6.1.5: Active TX frame matches latched tx_data and is immune to post-accept changes.
  property p_tx_frame_integrity;
    @(posedge clk) disable iff (!rst_n)
    !mon_tx_bit_mismatch;
  endproperty
  a_tx_frame_integrity: assert property (p_tx_frame_integrity)
    else $error("SVA FAIL [TX-INTEGRITY]: tx_serial mismatch vs latched tx_data at %0t", $time);

  // =========================================================================
  // RX Auxiliary Protocol Monitor
  // =========================================================================
  logic mon_rx_line;
  assign mon_rx_line = ((ENABLE_LOOPBACK == 1) && loopback_en) ? tx_serial : rx_serial_in;

  logic mon_rx_ff1;
  logic mon_rx_ff2;
  logic mon_rx_prev;
  logic mon_rx_falling;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mon_rx_ff1  <= 1'b1;
      mon_rx_ff2  <= 1'b1;
      mon_rx_prev <= 1'b1;
    end else begin
      mon_rx_ff1  <= mon_rx_line;
      mon_rx_ff2  <= mon_rx_ff1;
      mon_rx_prev <= mon_rx_ff2;
    end
  end

  assign mon_rx_falling = mon_rx_prev && !mon_rx_ff2;

  typedef enum logic [2:0] {
    MON_RX_IDLE       = 3'd0,
    MON_RX_START      = 3'd1,
    MON_RX_DATA       = 3'd2,
    MON_RX_STOP       = 3'd3,
    MON_RX_WAIT_PULSE = 3'd4,
    MON_RX_WAIT_IDLE  = 3'd5
  } mon_rx_state_t;

  mon_rx_state_t mon_rx_state;
  int unsigned   mon_rx_cyc;
  logic [2:0]    mon_rx_bit_idx;
  logic [7:0]    mon_rx_shift;
  logic          mon_rx_exp_good_stop;
  logic          mon_rx_pulse_timeout;
  logic          mon_rx_bad_pulse;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mon_rx_state         <= MON_RX_IDLE;
      mon_rx_cyc           <= 0;
      mon_rx_bit_idx       <= 3'd0;
      mon_rx_shift         <= 8'h00;
      mon_rx_exp_good_stop <= 1'b0;
      mon_rx_pulse_timeout <= 1'b0;
      mon_rx_bad_pulse     <= 1'b0;
    end else begin
      mon_rx_pulse_timeout <= 1'b0;
      mon_rx_bad_pulse     <= 1'b0;

      case (mon_rx_state)
        MON_RX_IDLE: begin
          mon_rx_cyc <= 0;
          if (mon_rx_falling) begin
            mon_rx_state <= MON_RX_START;
          end
        end

        MON_RX_START: begin
          if (mon_rx_cyc == RX_START_CHK) begin
            if (mon_rx_ff2 == 1'b0) begin
              mon_rx_bit_idx <= 3'd0;
              mon_rx_state   <= MON_RX_DATA;
            end else begin
              mon_rx_state <= MON_RX_IDLE;
            end
          end
          mon_rx_cyc <= mon_rx_cyc + 1;
        end

        MON_RX_DATA: begin
          if (mon_rx_cyc == bit_center_cyc(int'(mon_rx_bit_idx) + 1)) begin
            mon_rx_shift <= {mon_rx_ff2, mon_rx_shift[7:1]};
            if (mon_rx_bit_idx == 3'd7) begin
              mon_rx_state <= MON_RX_STOP;
            end else begin
              mon_rx_bit_idx <= mon_rx_bit_idx + 3'd1;
            end
          end
          mon_rx_cyc <= mon_rx_cyc + 1;
        end

        MON_RX_STOP: begin
          if (mon_rx_cyc == RX_STOP_CHK) begin
            mon_rx_exp_good_stop <= mon_rx_ff2;
            mon_rx_cyc           <= 0;
            mon_rx_state         <= MON_RX_WAIT_PULSE;
          end else begin
            mon_rx_cyc <= mon_rx_cyc + 1;
          end
        end

        MON_RX_WAIT_PULSE: begin
          if (rx_valid || framing_error) begin
            if (mon_rx_exp_good_stop) begin
              if (!rx_valid || framing_error || (rx_data !== mon_rx_shift)) begin
                mon_rx_bad_pulse <= 1'b1;
              end
              mon_rx_state <= MON_RX_IDLE;
            end else begin
              if (rx_valid || !framing_error) begin
                mon_rx_bad_pulse <= 1'b1;
              end
              mon_rx_state <= mon_rx_ff2 ? MON_RX_IDLE : MON_RX_WAIT_IDLE;
            end
          end else if (mon_rx_cyc >= RX_PULSE_MAX) begin
            mon_rx_pulse_timeout <= 1'b1;
            mon_rx_state         <= MON_RX_IDLE;
          end else begin
            mon_rx_cyc <= mon_rx_cyc + 1;
          end
        end

        MON_RX_WAIT_IDLE: begin
          if (mon_rx_ff2 == 1'b1) begin
            mon_rx_state <= MON_RX_IDLE;
          end
        end

        default: mon_rx_state <= MON_RX_IDLE;
      endcase
    end
  end

  // Spec 6.2.1: rx_valid must never stay high > 1 clock cycle.
  property p_rx_valid_one_cycle;
    @(posedge clk) disable iff (!rst_n)
    rx_valid |=> !rx_valid;
  endproperty
  a_rx_valid_one_cycle: assert property (p_rx_valid_one_cycle)
    else $error("SVA FAIL [RX-VALID-1CYC]: rx_valid high > 1 cycle at %0t", $time);

  // Spec 6.2.3: framing_error must never stay high > 1 clock cycle.
  property p_rx_ferr_one_cycle;
    @(posedge clk) disable iff (!rst_n)
    framing_error |=> !framing_error;
  endproperty
  a_rx_ferr_one_cycle: assert property (p_rx_ferr_one_cycle)
    else $error("SVA FAIL [RX-FERR-1CYC]: framing_error high > 1 cycle at %0t", $time);

  // Spec 6.2.5: rx_valid and framing_error are mutually exclusive.
  property p_rx_valid_ferr_mutex;
    @(posedge clk) disable iff (!rst_n)
    !(rx_valid && framing_error);
  endproperty
  a_rx_valid_ferr_mutex: assert property (p_rx_valid_ferr_mutex)
    else $error("SVA FAIL [RX-MUTEX]: rx_valid and framing_error high together at %0t", $time);

  // Spec 6.2.6: framing_error must not overwrite last valid rx_data.
  property p_rx_data_retention_on_ferr;
    @(posedge clk) disable iff (!rst_n)
    (past_valid && framing_error) |-> $stable(rx_data);
  endproperty
  a_rx_data_retention_on_ferr: assert property (p_rx_data_retention_on_ferr)
    else $error("SVA FAIL [RX-RETENTION]: rx_data changed during framing_error at %0t", $time);

  // Spec 6.2.2, 6.2.3, 6.2.4: Valid stop -> rx_valid & matching rx_data; bad stop -> framing_error & !rx_valid.
  property p_rx_frame_outcome;
    @(posedge clk) disable iff (!rst_n)
    (!mon_rx_bad_pulse && !mon_rx_pulse_timeout);
  endproperty
  a_rx_frame_outcome: assert property (p_rx_frame_outcome)
    else $error("SVA FAIL [RX-OUTCOME]: bad_pulse=%0b timeout=%0b at %0t",
                mon_rx_bad_pulse, mon_rx_pulse_timeout, $time);

  // =========================================================================
  // Companion Cover Properties (Non-Vacuity Verification)
  // =========================================================================
  c_tx_accept:       cover property (@(posedge clk) disable iff (!rst_n) (tx_valid && tx_ready));
  c_tx_back_to_back: cover property (@(posedge clk) disable iff (!rst_n) ($rose(tx_ready) && tx_valid));
  c_rx_valid:        cover property (@(posedge clk) disable iff (!rst_n) rx_valid);
  c_rx_ferr:         cover property (@(posedge clk) disable iff (!rst_n) framing_error);
  c_loopback_tx_rx:  cover property (@(posedge clk) disable iff (!rst_n) (loopback_en && rx_valid));

endmodule
