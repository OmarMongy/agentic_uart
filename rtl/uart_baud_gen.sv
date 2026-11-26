// Parameterized GCD-reduced Bresenham fractional baud/oversampling tick generator.
// Emits a single-cycle synchronous clock-enable pulse (`tick`) at
// frequency (BAUD_RATE * OVERSAMPLE) with zero long-term average frequency error.
module uart_baud_gen #(
  parameter int unsigned CLK_FREQ   = 50_000_000,
  parameter int unsigned BAUD_RATE  = 115_200,
  parameter int unsigned OVERSAMPLE = 16
) (
  input  logic clk,
  input  logic rst_n,
  input  logic en,
  input  logic clr,
  output logic tick
);

  function automatic logic [63:0] calc_gcd(
    input logic [63:0] a,
    input logic [63:0] b
  );
    logic [63:0] x;
    logic [63:0] y;
    logic [63:0] t;
    begin
      x = a;
      y = b;
      // Fixed iteration bound supports static elaboration across synthesis/lint tools.
      for (int i = 0; i < 128; i++) begin
        if (y != 64'd0) begin
          t = x % y;
          x = y;
          y = t;
        end
      end
      calc_gcd = (x == 64'd0) ? 64'd1 : x;
    end
  endfunction

  localparam logic [63:0] CLK_FREQ_U    = 64'(CLK_FREQ);
  localparam logic [63:0] TARGET_FREQ_U = 64'(BAUD_RATE) * 64'(OVERSAMPLE);

  // Parameter validation at elaboration time
  generate
    if (CLK_FREQ == 0) begin : gen_err_clk_freq
      $error("uart_baud_gen: CLK_FREQ must be > 0 (got %0d)", CLK_FREQ);
    end
    if (BAUD_RATE == 0) begin : gen_err_baud_rate
      $error("uart_baud_gen: BAUD_RATE must be > 0 (got %0d)", BAUD_RATE);
    end
    if (OVERSAMPLE == 0) begin : gen_err_oversample
      $error("uart_baud_gen: OVERSAMPLE must be > 0 (got %0d)", OVERSAMPLE);
    end
    if (TARGET_FREQ_U > CLK_FREQ_U) begin : gen_err_ratio
      $error("uart_baud_gen: BAUD_RATE * OVERSAMPLE (%0d) exceeds CLK_FREQ (%0d)",
             TARGET_FREQ_U, CLK_FREQ_U);
    end
  endgenerate

  localparam logic [63:0] GCD_VAL =
    ((CLK_FREQ_U == 64'd0) || (TARGET_FREQ_U == 64'd0)) ? 64'd1 :
    calc_gcd(CLK_FREQ_U, TARGET_FREQ_U);

  localparam logic [63:0] MOD_VAL =
    (CLK_FREQ_U == 64'd0) ? 64'd1 : (CLK_FREQ_U / GCD_VAL);

  localparam logic [63:0] INC_VAL =
    (TARGET_FREQ_U == 64'd0) ? 64'd1 :
    ((TARGET_FREQ_U / GCD_VAL) > MOD_VAL ? MOD_VAL : (TARGET_FREQ_U / GCD_VAL));

  localparam int ACC_W =
    ((MOD_VAL + INC_VAL) <= 64'd2) ? 2 : $clog2(MOD_VAL + INC_VAL);

  localparam logic [ACC_W-1:0] MOD_C = MOD_VAL[ACC_W-1:0];
  localparam logic [ACC_W-1:0] INC_C = INC_VAL[ACC_W-1:0];

  logic [ACC_W-1:0] acc;
  logic [ACC_W-1:0] acc_sum;

  always_comb begin
    acc_sum = acc + INC_C;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc  <= '0;
      tick <= 1'b0;
    end else if (clr) begin
      // Pre-load INC_C so the first registered `tick` lands at exact MOD_VAL/INC_VAL cycles.
      acc  <= (INC_C >= MOD_C) ? '0 : INC_C;
      tick <= (INC_C >= MOD_C);
    end else if (en) begin
      if (acc_sum >= MOD_C) begin
        acc  <= acc_sum - MOD_C;
        tick <= 1'b1;
      end else begin
        acc  <= acc_sum;
        tick <= 1'b0;
      end
    end else begin
      tick <= 1'b0;
    end
  end

endmodule
