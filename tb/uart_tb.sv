`timescale 1ns/1ps

// Self-checking verification environment covering:
// - Standalone uart_tx (T01-T04)
// - Standalone uart_rx (T05-T09)
// - Integrated uart_top + SVA (T10-T12)
// - Non-default / non-divisible parameters & ENABLE_LOOPBACK=0 (T13)
module uart_tb;

  localparam int unsigned CLK_FREQ_50M  = 50_000_000;
  localparam int unsigned CLK_FREQ_12M5 = 12_500_000;
  localparam int unsigned BAUD_115200   = 115_200;
  localparam int unsigned BAUD_460800   = 460_800;
  localparam int unsigned OVERSAMPLE    = 16;

  // Derived bit periods in nanoseconds for asynchronous serial BFMs
  localparam real BIT_NS_50M_115200  = 1.0e9 / 115200.0;
  localparam real BIT_NS_50M_460800  = 1.0e9 / 460800.0;
  localparam int unsigned BIT_CLKS_DEF = CLK_FREQ_50M / BAUD_115200; // 434

  // Clocks
  logic clk_50m  = 1'b0;
  logic clk_12m5 = 1'b0;
  initial forever #10ns clk_50m  = ~clk_50m;  // 50 MHz (20 ns period)
  initial forever #40ns clk_12m5 = ~clk_12m5; // 12.5 MHz (80 ns period)

  // Standalone TX signals
  logic       tx_rst_n;
  logic [7:0] st_tx_data;
  logic       st_tx_valid;
  logic       st_tx_ready;
  logic       st_tx_serial;

  // Standalone RX signals
  logic       rx_rst_n;
  logic       st_rx_serial;
  logic [7:0] st_rx_data;
  logic       st_rx_valid;
  logic       st_rx_ferr;

  // Top-level default DUT signals (50 MHz / 115200 / ENABLE_LOOPBACK=1)
  logic       top_rst_n;
  logic       top_loopback_en;
  logic [7:0] top_tx_data;
  logic       top_tx_valid;
  logic       top_tx_ready;
  logic       top_tx_serial;
  logic       top_rx_serial_in;
  logic [7:0] top_rx_data;
  logic       top_rx_valid;
  logic       top_rx_ferr;

  // Top-level alternate DUT signals (50 MHz / 460800 / ENABLE_LOOPBACK=0)
  logic       alt_rst_n;
  logic       alt_loopback_en;
  logic [7:0] alt_tx_data;
  logic       alt_tx_valid;
  logic       alt_tx_ready;
  logic       alt_tx_serial;
  logic       alt_rx_serial_in;
  logic [7:0] alt_rx_data;
  logic       alt_rx_valid;
  logic       alt_rx_ferr;

  // Top-level 12.5 MHz DUT signals (12.5 MHz / 115200 / ENABLE_LOOPBACK=1)
  logic       c12_rst_n;
  logic       c12_loopback_en;
  logic [7:0] c12_tx_data;
  logic       c12_tx_valid;
  logic       c12_tx_ready;
  logic       c12_tx_serial;
  logic       c12_rx_serial_in;
  logic [7:0] c12_rx_data;
  logic       c12_rx_valid;
  logic       c12_rx_ferr;

  // Instantiate DUTs
  uart_tx #(
    .CLK_FREQ   (CLK_FREQ_50M),
    .BAUD_RATE  (BAUD_115200),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_tx_dut (
    .clk       (clk_50m),
    .rst_n     (tx_rst_n),
    .tx_data   (st_tx_data),
    .tx_valid  (st_tx_valid),
    .tx_ready  (st_tx_ready),
    .tx_serial (st_tx_serial)
  );

  uart_rx #(
    .CLK_FREQ   (CLK_FREQ_50M),
    .BAUD_RATE  (BAUD_115200),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_rx_dut (
    .clk           (clk_50m),
    .rst_n         (rx_rst_n),
    .rx_serial     (st_rx_serial),
    .rx_data       (st_rx_data),
    .rx_valid      (st_rx_valid),
    .framing_error (st_rx_ferr)
  );

  uart_top #(
    .CLK_FREQ        (CLK_FREQ_50M),
    .BAUD_RATE       (BAUD_115200),
    .OVERSAMPLE      (OVERSAMPLE),
    .ENABLE_LOOPBACK (1)
  ) u_top_dut (
    .clk           (clk_50m),
    .rst_n         (top_rst_n),
    .loopback_en   (top_loopback_en),
    .tx_data       (top_tx_data),
    .tx_valid      (top_tx_valid),
    .tx_ready      (top_tx_ready),
    .tx_serial     (top_tx_serial),
    .rx_serial_in  (top_rx_serial_in),
    .rx_data       (top_rx_data),
    .rx_valid      (top_rx_valid),
    .framing_error (top_rx_ferr)
  );

  uart_sva #(
    .CLK_FREQ        (CLK_FREQ_50M),
    .BAUD_RATE       (BAUD_115200),
    .OVERSAMPLE      (OVERSAMPLE),
    .ENABLE_LOOPBACK (1)
  ) u_top_sva (
    .clk           (clk_50m),
    .rst_n         (top_rst_n),
    .loopback_en   (top_loopback_en),
    .tx_data       (top_tx_data),
    .tx_valid      (top_tx_valid),
    .tx_ready      (top_tx_ready),
    .tx_serial     (top_tx_serial),
    .rx_serial_in  (top_rx_serial_in),
    .rx_data       (top_rx_data),
    .rx_valid      (top_rx_valid),
    .framing_error (top_rx_ferr)
  );

  uart_top #(
    .CLK_FREQ        (CLK_FREQ_50M),
    .BAUD_RATE       (BAUD_460800),
    .OVERSAMPLE      (OVERSAMPLE),
    .ENABLE_LOOPBACK (0)
  ) u_top_alt (
    .clk           (clk_50m),
    .rst_n         (alt_rst_n),
    .loopback_en   (alt_loopback_en),
    .tx_data       (alt_tx_data),
    .tx_valid      (alt_tx_valid),
    .tx_ready      (alt_tx_ready),
    .tx_serial     (alt_tx_serial),
    .rx_serial_in  (alt_rx_serial_in),
    .rx_data       (alt_rx_data),
    .rx_valid      (alt_rx_valid),
    .framing_error (alt_rx_ferr)
  );

  uart_sva #(
    .CLK_FREQ        (CLK_FREQ_50M),
    .BAUD_RATE       (BAUD_460800),
    .OVERSAMPLE      (OVERSAMPLE),
    .ENABLE_LOOPBACK (0)
  ) u_alt_sva (
    .clk           (clk_50m),
    .rst_n         (alt_rst_n),
    .loopback_en   (alt_loopback_en),
    .tx_data       (alt_tx_data),
    .tx_valid      (alt_tx_valid),
    .tx_ready      (alt_tx_ready),
    .tx_serial     (alt_tx_serial),
    .rx_serial_in  (alt_rx_serial_in),
    .rx_data       (alt_rx_data),
    .rx_valid      (alt_rx_valid),
    .framing_error (alt_rx_ferr)
  );

  uart_top #(
    .CLK_FREQ        (CLK_FREQ_12M5),
    .BAUD_RATE       (BAUD_115200),
    .OVERSAMPLE      (OVERSAMPLE),
    .ENABLE_LOOPBACK (1)
  ) u_top_12m (
    .clk           (clk_12m5),
    .rst_n         (c12_rst_n),
    .loopback_en   (c12_loopback_en),
    .tx_data       (c12_tx_data),
    .tx_valid      (c12_tx_valid),
    .tx_ready      (c12_tx_ready),
    .tx_serial     (c12_tx_serial),
    .rx_serial_in  (c12_rx_serial_in),
    .rx_data       (c12_rx_data),
    .rx_valid      (c12_rx_valid),
    .framing_error (c12_rx_ferr)
  );

  uart_sva #(
    .CLK_FREQ        (CLK_FREQ_12M5),
    .BAUD_RATE       (BAUD_115200),
    .OVERSAMPLE      (OVERSAMPLE),
    .ENABLE_LOOPBACK (1)
  ) u_12m_sva (
    .clk           (clk_12m5),
    .rst_n         (c12_rst_n),
    .loopback_en   (c12_loopback_en),
    .tx_data       (c12_tx_data),
    .tx_valid      (c12_tx_valid),
    .tx_ready      (c12_tx_ready),
    .tx_serial     (c12_tx_serial),
    .rx_serial_in  (c12_rx_serial_in),
    .rx_data       (c12_rx_data),
    .rx_valid      (c12_rx_valid),
    .framing_error (c12_rx_ferr)
  );

  // =========================================================================
  // Scoreboard, Coverage & PRNG
  // =========================================================================
  int unsigned err_count  = 0;
  int unsigned pass_count = 0;

  // Explicit specification coverage counters
  int unsigned cov_tx_frames        = 0;
  int unsigned cov_rx_frames        = 0;
  int unsigned cov_rx_ferr          = 0;
  int unsigned cov_rx_glitches      = 0;
  int unsigned cov_loopback_frames  = 0;
  int unsigned cov_fullduplex_ops   = 0;
  int unsigned cov_reset_mid_frame  = 0;
  int unsigned cov_alt_param_frames = 0;
  logic [7:0]  cov_bits_seen_0      = 8'h00;
  logic [7:0]  cov_bits_seen_1      = 8'h00;

  logic [31:0] prng_state = 32'hCAFE_BEEF;
  function automatic logic [7:0] next_rand_byte();
    begin
      prng_state = {prng_state[30:0], prng_state[31] ^ prng_state[21] ^ prng_state[1] ^ prng_state[0]};
      next_rand_byte = prng_state[7:0];
    end
  endfunction

  task automatic check_cond(input bit cond, input string test_name, input string msg);
    if (!cond) begin
      $display("[FAIL] %0t | %s | %s", $time, test_name, msg);
      err_count++;
    end else begin
      pass_count++;
    end
  endtask

  task automatic record_byte_cov(input logic [7:0] b);
    cov_bits_seen_1 = cov_bits_seen_1 | b;
    cov_bits_seen_0 = cov_bits_seen_0 | (~b);
  endtask

  // Independent golden serial frame capture on st_tx_serial (50 MHz / 115200)
  task automatic monitor_st_tx_frame(
    input  logic [7:0] exp_byte,
    input  string      test_name
  );
    int unsigned wait_cycs;
    logic [7:0]  rx_byte;
    begin
      wait_cycs = 0;
      while (st_tx_serial === 1'b1) begin
        @(posedge clk_50m);
        wait_cycs++;
        if (wait_cycs > (BIT_CLKS_DEF * 3)) begin
          check_cond(1'b0, test_name, "Timeout waiting for TX start bit");
          return;
        end
      end

      // Sample start bit at midpoint
      repeat (BIT_CLKS_DEF / 2) @(posedge clk_50m);
      check_cond(st_tx_serial === 1'b0, test_name, "Start bit not 0 at midpoint");
      check_cond(st_tx_ready === 1'b0, test_name, "tx_ready must be 0 during start bit");

      // Sample 8 data bits LSB-first
      for (int b = 0; b < 8; b++) begin
        repeat (BIT_CLKS_DEF) @(posedge clk_50m);
        rx_byte[b] = st_tx_serial;
        check_cond(st_tx_ready === 1'b0, test_name, "tx_ready must be 0 during data bit");
      end

      // Sample stop bit at midpoint
      repeat (BIT_CLKS_DEF) @(posedge clk_50m);
      check_cond(st_tx_serial === 1'b1, test_name, "Stop bit not 1 at midpoint");
      check_cond(st_tx_ready === 1'b0, test_name, "tx_ready must be 0 during stop bit");
      check_cond(rx_byte === exp_byte, test_name,
                 $sformatf("Captured TX byte 0x%02x != expected 0x%02x", rx_byte, exp_byte));

      // Wait for tx_ready return after stop bit completes
      wait_cycs = 0;
      while (st_tx_ready !== 1'b1) begin
        @(posedge clk_50m);
        wait_cycs++;
        if (wait_cycs > BIT_CLKS_DEF) begin
          check_cond(1'b0, test_name, "Timeout waiting for tx_ready after stop bit");
          return;
        end
      end
      cov_tx_frames++;
      record_byte_cov(exp_byte);
    end
  endtask

  // Independent asynchronous serial driver BFM
  task automatic drive_serial_byte(
    ref    logic       serial_pin,
    input  logic [7:0] data_byte,
    input  bit         bad_stop,
    input  real        bit_ns,
    input  real        phase_offset_ns
  );
    begin
      if (phase_offset_ns > 0.0) begin
        #(phase_offset_ns * 1ns);
      end
      // Start bit
      serial_pin = 1'b0;
      #(bit_ns * 1ns);
      // 8 data bits LSB-first
      for (int i = 0; i < 8; i++) begin
        serial_pin = data_byte[i];
        #(bit_ns * 1ns);
      end
      // Stop bit
      serial_pin = bad_stop ? 1'b0 : 1'b1;
      #(bit_ns * 1ns);
      // Return idle high
      serial_pin = 1'b1;
    end
  endtask

  // =========================================================================
  // Test Sequences
  // =========================================================================
  initial begin
    $dumpfile("waveforms/uart_tb.vcd");
    $dumpvars(0, uart_tb);

    // Initialize all interfaces (start rst_n high so 1->0 edge triggers async reset)
    tx_rst_n         = 1'b1;
    st_tx_data       = 8'h00;
    st_tx_valid      = 1'b0;

    rx_rst_n         = 1'b1;
    st_rx_serial     = 1'b1;

    top_rst_n        = 1'b1;
    top_loopback_en  = 1'b1;
    top_tx_data      = 8'h00;
    top_tx_valid     = 1'b0;
    top_rx_serial_in = 1'b1;

    alt_rst_n        = 1'b1;
    alt_loopback_en  = 1'b1; // Ignored when ENABLE_LOOPBACK=0
    alt_tx_data      = 8'h00;
    alt_tx_valid     = 1'b0;
    alt_rx_serial_in = 1'b1;

    c12_rst_n        = 1'b1;
    c12_loopback_en  = 1'b1;
    c12_tx_data      = 8'h00;
    c12_tx_valid     = 1'b0;
    c12_rx_serial_in = 1'b1;

    // -----------------------------------------------------------------------
    // T01 & T05: Reset and Idle State Checks
    // -----------------------------------------------------------------------
    #1ns;
    tx_rst_n  = 1'b0;
    rx_rst_n  = 1'b0;
    top_rst_n = 1'b0;
    alt_rst_n = 1'b0;
    c12_rst_n = 1'b0;
    #1ns;
    check_cond(st_tx_serial === 1'b1, "T01_RST", "TX serial must be 1 during reset");
    check_cond(st_tx_ready === 1'b0,  "T01_RST", "TX ready must be 0 during reset");
    check_cond(st_rx_valid === 1'b0,  "T05_RST", "RX valid must be 0 during reset");
    check_cond(st_rx_ferr === 1'b0,   "T05_RST", "RX framing_error must be 0 during reset");
    check_cond(st_rx_data === 8'h00,  "T05_RST", "RX data must be 0x00 during reset");

    repeat (5) @(posedge clk_50m);
    tx_rst_n  = 1'b1;
    rx_rst_n  = 1'b1;
    top_rst_n = 1'b1;
    alt_rst_n = 1'b1;
    @(posedge clk_12m5);
    c12_rst_n = 1'b1;

    repeat (2) @(posedge clk_50m);
    #1ns;
    check_cond(st_tx_ready === 1'b1, "T01_IDLE", "TX ready must be 1 after reset release");
    check_cond(st_tx_serial === 1'b1, "T01_IDLE", "TX serial must remain 1 while idle");

    // -----------------------------------------------------------------------
    // T02: Standalone TX Directed Patterns (0x00, 0xFF, 0xA5, 0x3C)
    // -----------------------------------------------------------------------
    begin
      logic [7:0] patterns [4] = '{8'h00, 8'hFF, 8'hA5, 8'h3C};
      foreach (patterns[idx]) begin
        @(negedge clk_50m);
        st_tx_data  = patterns[idx];
        st_tx_valid = 1'b1;
        @(posedge clk_50m);
        #1ns;
        st_tx_valid = 1'b0;
        monitor_st_tx_frame(patterns[idx], $sformatf("T02_PAT_%02x", patterns[idx]));
      end
    end

    // -----------------------------------------------------------------------
    // T03: TX Data Stability Under Post-Accept Mutation + Back-to-Back Frames
    // -----------------------------------------------------------------------
    begin
      logic [7:0] b1 = 8'h5A;
      logic [7:0] b2 = 8'hC3;
      @(negedge clk_50m);
      st_tx_data  = b1;
      st_tx_valid = 1'b1;
      @(posedge clk_50m);
      #1ns;
      // Mutate tx_data and keep tx_valid=1 with next byte while TX is busy
      st_tx_data  = b2;
      monitor_st_tx_frame(b1, "T03_MUTATE_HOLD");
      // Because st_tx_valid stayed 1, b2 is accepted immediately on the first idle cycle
      @(posedge clk_50m);
      #1ns;
      st_tx_valid = 1'b0;
      monitor_st_tx_frame(b2, "T03_BACK2BACK");
    end

    // -----------------------------------------------------------------------
    // T04: Mid-Frame Reset During Active TX Transmission
    // -----------------------------------------------------------------------
    @(negedge clk_50m);
    st_tx_data  = 8'h55;
    st_tx_valid = 1'b1;
    @(posedge clk_50m);
    #1ns;
    st_tx_valid = 1'b0;
    repeat (BIT_CLKS_DEF * 3) @(posedge clk_50m); // Mid-frame in TX_DATA
    #2ns;
    tx_rst_n = 1'b0;
    #2ns;
    check_cond(st_tx_serial === 1'b1, "T04_RST_MID", "TX serial must return to 1 on mid-frame reset");
    check_cond(st_tx_ready === 1'b0,  "T04_RST_MID", "TX ready must deassert on mid-frame reset");
    cov_reset_mid_frame++;
    repeat (4) @(posedge clk_50m);
    tx_rst_n = 1'b1;
    repeat (2) @(posedge clk_50m);
    // Confirm clean TX recovery after reset
    @(negedge clk_50m);
    st_tx_data  = 8'h96;
    st_tx_valid = 1'b1;
    @(posedge clk_50m);
    #1ns;
    st_tx_valid = 1'b0;
    monitor_st_tx_frame(8'h96, "T04_RECOVER");

    // -----------------------------------------------------------------------
    // T06: Standalone RX Directed & Sub-Bit Phase-Offset / Baud-Mismatch Tests
    // -----------------------------------------------------------------------
    begin
      logic [7:0] rx_pats [5] = '{8'h00, 8'hFF, 8'hA5, 8'h3C, 8'h7E};
      real        baud_factors [5] = '{1.0, 0.985, 1.015, 0.99, 1.01};
      real        offsets [5] = '{7.0, 19.0, 3.0, 11.0, 15.0};
      logic [7:0] got_byte;
      bit         saw_valid;
      int unsigned valid_len;
      int unsigned w;

      foreach (rx_pats[i]) begin
        saw_valid = 1'b0;
        valid_len = 0;
        fork
          drive_serial_byte(st_rx_serial, rx_pats[i], 1'b0,
                            BIT_NS_50M_115200 * baud_factors[i], offsets[i]);
          begin
            for (w = 0; w < BIT_CLKS_DEF * 13; w++) begin
              @(posedge clk_50m);
              #1ns;
              check_cond(!(st_rx_valid && st_rx_ferr), "T06_MUTEX", "valid and ferr high together");
              if (st_rx_valid) begin
                saw_valid = 1'b1;
                valid_len++;
                got_byte = st_rx_data;
              end
              check_cond(!st_rx_ferr, "T06_NO_FERR", "Unexpected framing error on valid RX frame");
            end
          end
        join
        check_cond(saw_valid, "T06_VALID", $sformatf("Did not see rx_valid for 0x%02x", rx_pats[i]));
        check_cond(valid_len == 1, "T06_1CYC", "rx_valid must be asserted for exactly 1 cycle");
        check_cond(got_byte === rx_pats[i], "T06_DATA",
                   $sformatf("RX got 0x%02x != expected 0x%02x", got_byte, rx_pats[i]));
        cov_rx_frames++;
        record_byte_cov(rx_pats[i]);
      end
    end

    // -----------------------------------------------------------------------
    // T07: Framing Error, Data Retention, and Recovery
    // -----------------------------------------------------------------------
    begin
      logic [7:0] prev_good = st_rx_data; // 0x7E from T06
      bit         saw_ferr;
      int unsigned ferr_len;
      bit         saw_valid;
      int unsigned w;

      saw_ferr = 1'b0;
      ferr_len = 0;
      saw_valid = 1'b0;
      fork
        drive_serial_byte(st_rx_serial, 8'hE1, 1'b1, BIT_NS_50M_115200, 5.0);
        begin
          for (w = 0; w < BIT_CLKS_DEF * 13; w++) begin
            @(posedge clk_50m);
            #1ns;
            if (st_rx_ferr) begin
              saw_ferr = 1'b1;
              ferr_len++;
              check_cond(st_rx_data === prev_good, "T07_RETAIN",
                         "rx_data overwritten during framing_error");
            end
            if (st_rx_valid) saw_valid = 1'b1;
          end
        end
      join
      check_cond(saw_ferr, "T07_FERR", "Framing error not asserted on low stop bit");
      check_cond(ferr_len == 1, "T07_FERR_1CYC", "framing_error must last exactly 1 cycle");
      check_cond(!saw_valid, "T07_NO_VALID", "rx_valid must not assert on bad stop bit");
      check_cond(st_rx_data === prev_good, "T07_RETAIN_POST", "rx_data did not retain prior byte");
      cov_rx_ferr++;

      // Recovery frame after framing error
      saw_valid = 1'b0;
      fork
        drive_serial_byte(st_rx_serial, 8'h4D, 1'b0, BIT_NS_50M_115200, 9.0);
        begin
          for (w = 0; w < BIT_CLKS_DEF * 13; w++) begin
            @(posedge clk_50m);
            #1ns;
            if (st_rx_valid) saw_valid = 1'b1;
            check_cond(!st_rx_ferr, "T07_REC_NO_FERR", "Unexpected ferr during recovery frame");
          end
        end
      join
      check_cond(saw_valid && (st_rx_data === 8'h4D), "T07_RECOVER", "Failed recovery after ferr");
      cov_rx_frames++;
    end

    // -----------------------------------------------------------------------
    // T08: False-Start / Short Glitch Rejection on RX
    // -----------------------------------------------------------------------
    begin
      real glitch_widths_ns [3] = '{20.0, 1500.0, 3000.0}; // 1 clk, ~2.8 ticks, ~5.5 ticks (< 0.5 bit = 4340 ns)
      foreach (glitch_widths_ns[g]) begin
        st_rx_serial = 1'b0;
        #(glitch_widths_ns[g] * 1ns);
        st_rx_serial = 1'b1;
        for (int w = 0; w < BIT_CLKS_DEF * 12; w++) begin
          @(posedge clk_50m);
          #1ns;
          check_cond(!st_rx_valid && !st_rx_ferr, "T08_GLITCH",
                     "Short low glitch falsely triggered RX output");
        end
        cov_rx_glitches++;
      end
    end

    // -----------------------------------------------------------------------
    // T09: Mid-Frame Reset During Active RX Reception
    // -----------------------------------------------------------------------
    fork
      drive_serial_byte(st_rx_serial, 8'hB7, 1'b0, BIT_NS_50M_115200, 4.0);
      begin
        repeat (BIT_CLKS_DEF * 4) @(posedge clk_50m);
        #3ns;
        rx_rst_n = 1'b0;
        #2ns;
        check_cond(st_rx_data === 8'h00 && !st_rx_valid && !st_rx_ferr,
                   "T09_RST_MID", "RX outputs did not clear on mid-frame reset");
        cov_reset_mid_frame++;
        repeat (4) @(posedge clk_50m);
        rx_rst_n = 1'b1;
      end
    join
    // Wait for aborted serial activity to finish and RX line to settle idle
    repeat (BIT_CLKS_DEF * 12) @(posedge clk_50m);
    // Verify RX recovers cleanly
    begin
      bit saw_rec = 1'b0;
      fork
        drive_serial_byte(st_rx_serial, 8'h2A, 1'b0, BIT_NS_50M_115200, 6.0);
        for (int w = 0; w < BIT_CLKS_DEF * 13; w++) begin
          @(posedge clk_50m);
          #1ns;
          if (st_rx_valid) saw_rec = 1'b1;
        end
      join
      check_cond(saw_rec && (st_rx_data === 8'h2A), "T09_RECOVER", "RX failed post-reset recovery");
      cov_rx_frames++;
    end

    // -----------------------------------------------------------------------
    // T10: Top-Level Loopback Self-Test (Directed + Random Back-to-Back)
    // -----------------------------------------------------------------------
    begin
      logic [7:0] lb_bytes [10];
      int unsigned rx_idx;
      int unsigned wait_c;

      lb_bytes[0] = 8'h00;
      lb_bytes[1] = 8'hFF;
      lb_bytes[2] = 8'hA5;
      lb_bytes[3] = 8'h3C;
      for (int i = 4; i < 10; i++) begin
        lb_bytes[i] = next_rand_byte();
      end

      top_loopback_en = 1'b1;
      rx_idx = 0;

      fork
        // TX driver (back-to-back stream)
        begin
          for (int i = 0; i < 10; i++) begin
            while (!top_tx_ready) @(posedge clk_50m);
            @(negedge clk_50m);
            top_tx_data  = lb_bytes[i];
            top_tx_valid = 1'b1;
            @(posedge clk_50m);
            #1ns;
            top_tx_valid = 1'b0;
          end
        end
        // RX monitor
        begin
          wait_c = 0;
          while (rx_idx < 10) begin
            @(posedge clk_50m);
            #1ns;
            check_cond(!top_rx_ferr, "T10_NO_FERR", "Unexpected framing error in loopback");
            if (top_rx_valid) begin
              check_cond(top_rx_data === lb_bytes[rx_idx], "T10_LB_MATCH",
                         $sformatf("Loopback byte[%0d] got 0x%02x != 0x%02x",
                                   rx_idx, top_rx_data, lb_bytes[rx_idx]));
              rx_idx++;
              cov_loopback_frames++;
            end
            wait_c++;
            if (wait_c > (BIT_CLKS_DEF * 130)) begin
              check_cond(1'b0, "T10_TIMEOUT", "Loopback RX timed out");
              break;
            end
          end
        end
      join
      while (!top_tx_ready) @(posedge clk_50m);
    end

    // -----------------------------------------------------------------------
    // T11: Normal Mode (loopback_en=0) Isolation & Full-Duplex Simultaneous
    // -----------------------------------------------------------------------
    begin
      logic [7:0] fd_tx_byte = 8'h6B;
      logic [7:0] fd_rx_byte = 8'hD4;
      bit         saw_fd_rx;
      logic [7:0] cap_fd_tx;

      top_loopback_en  = 1'b0;
      top_rx_serial_in = 1'b1;
      @(posedge clk_50m);

      // Part A: Isolation check (TX transmits while external rx_serial_in stays idle 1)
      @(negedge clk_50m);
      top_tx_data  = 8'hA3;
      top_tx_valid = 1'b1;
      @(posedge clk_50m);
      #1ns;
      top_tx_valid = 1'b0;
      while (!top_tx_ready) begin
        @(posedge clk_50m);
        #1ns;
        check_cond(!top_rx_valid && !top_rx_ferr, "T11_ISOLATION",
                   "RX falsely reacted to TX in normal mode");
      end

      // Part B: Simultaneous full-duplex TX (0x6B) and external RX (0xD4)
      saw_fd_rx = 1'b0;
      cap_fd_tx = 8'h00;
      fork
        begin
          @(negedge clk_50m);
          top_tx_data  = fd_tx_byte;
          top_tx_valid = 1'b1;
          @(posedge clk_50m);
          #1ns;
          top_tx_valid = 1'b0;
          // Capture top_tx_serial
          while (top_tx_serial === 1'b1) @(posedge clk_50m);
          repeat (BIT_CLKS_DEF / 2) @(posedge clk_50m);
          for (int b = 0; b < 8; b++) begin
            repeat (BIT_CLKS_DEF) @(posedge clk_50m);
            cap_fd_tx[b] = top_tx_serial;
          end
          repeat (BIT_CLKS_DEF) @(posedge clk_50m);
          check_cond(top_tx_serial === 1'b1, "T11_FD_TX_STOP", "FD TX stop bit != 1");
          check_cond(cap_fd_tx === fd_tx_byte, "T11_FD_TX_DATA", "FD TX serial mismatch");
        end
        begin
          drive_serial_byte(top_rx_serial_in, fd_rx_byte, 1'b0, BIT_NS_50M_115200, 120.0);
        end
        begin
          for (int w = 0; w < BIT_CLKS_DEF * 13; w++) begin
            @(posedge clk_50m);
            #1ns;
            if (top_rx_valid) begin
              saw_fd_rx = 1'b1;
              check_cond(top_rx_data === fd_rx_byte, "T11_FD_RX_DATA", "FD RX data mismatch");
            end
          end
        end
      join
      check_cond(saw_fd_rx, "T11_FD_RX_VALID", "FD RX valid not seen");
      while (!top_tx_ready) @(posedge clk_50m);
      cov_fullduplex_ops++;

      // Negative test in normal mode: low stop bit on rx_serial_in
      begin
        bit saw_nferr = 1'b0;
        fork
          drive_serial_byte(top_rx_serial_in, 8'h19, 1'b1, BIT_NS_50M_115200, 15.0);
          for (int w = 0; w < BIT_CLKS_DEF * 13; w++) begin
            @(posedge clk_50m);
            #1ns;
            if (top_rx_ferr) saw_nferr = 1'b1;
            check_cond(!top_rx_valid, "T11_NORM_BADSTOP_NOVALID", "rx_valid high on bad stop");
          end
        join
        check_cond(saw_nferr, "T11_NORM_BADSTOP_FERR", "framing_error missed in normal mode");
      end
    end

    // -----------------------------------------------------------------------
    // T12: Clean Mode Switching (Normal 0 -> Loopback 1 -> Normal 0)
    // -----------------------------------------------------------------------
    begin
      bit saw_sw_rx = 1'b0;
      top_loopback_en = 1'b1;
      repeat (5) @(posedge clk_50m);
      @(negedge clk_50m);
      top_tx_data  = 8'hF1;
      top_tx_valid = 1'b1;
      @(posedge clk_50m);
      #1ns;
      top_tx_valid = 1'b0;
      for (int w = 0; w < BIT_CLKS_DEF * 13; w++) begin
        @(posedge clk_50m);
        #1ns;
        if (top_rx_valid) begin
          saw_sw_rx = 1'b1;
          check_cond(top_rx_data === 8'hF1, "T12_SWITCH_LB", "Loopback data mismatch after switch");
        end
      end
      check_cond(saw_sw_rx, "T12_SWITCH_LB_V", "Loopback valid missing after mode switch");
      while (!top_tx_ready) @(posedge clk_50m);

      // Switch back to normal mode and receive external byte
      top_loopback_en = 1'b0;
      repeat (5) @(posedge clk_50m);
      saw_sw_rx = 1'b0;
      fork
        drive_serial_byte(top_rx_serial_in, 8'h0E, 1'b0, BIT_NS_50M_115200, 10.0);
        for (int w = 0; w < BIT_CLKS_DEF * 13; w++) begin
          @(posedge clk_50m);
          #1ns;
          if (top_rx_valid) begin
            saw_sw_rx = 1'b1;
            check_cond(top_rx_data === 8'h0E, "T12_SWITCH_NORM", "Normal RX mismatch after switch");
          end
        end
      join
      check_cond(saw_sw_rx, "T12_SWITCH_NORM_V", "Normal RX valid missing after mode switch");
    end

    // -----------------------------------------------------------------------
    // T13: Non-Default & Non-Divisible Parameters + ENABLE_LOOPBACK=0
    // -----------------------------------------------------------------------
    begin
      bit          saw_alt_rx = 1'b0;
      bit          saw_c12_rx = 1'b0;
      logic [7:0]  alt_tx_cap = 8'h00;
      int unsigned alt_bit_clks = CLK_FREQ_50M / BAUD_460800; // 108

      // Test u_top_alt (50 MHz / 460800 / ENABLE_LOOPBACK=0):
      // Even though alt_loopback_en == 1, RX must use alt_rx_serial_in only.
      fork
        begin
          @(negedge clk_50m);
          alt_tx_data  = 8'h3A;
          alt_tx_valid = 1'b1;
          @(posedge clk_50m);
          #1ns;
          alt_tx_valid = 1'b0;
          while (alt_tx_serial === 1'b1) @(posedge clk_50m);
          repeat (alt_bit_clks / 2) @(posedge clk_50m);
          for (int b = 0; b < 8; b++) begin
            repeat (alt_bit_clks) @(posedge clk_50m);
            alt_tx_cap[b] = alt_tx_serial;
          end
          repeat (alt_bit_clks) @(posedge clk_50m);
          check_cond(alt_tx_serial === 1'b1, "T13_ALT_STOP", "460800 TX stop bit != 1");
          check_cond(alt_tx_cap === 8'h3A, "T13_ALT_TX", "460800 TX data mismatch");
        end
        begin
          drive_serial_byte(alt_rx_serial_in, 8'hC5, 1'b0, BIT_NS_50M_460800, 15.0);
        end
        begin
          for (int w = 0; w < alt_bit_clks * 13; w++) begin
            @(posedge clk_50m);
            #1ns;
            if (alt_rx_valid) begin
              saw_alt_rx = 1'b1;
              check_cond(alt_rx_data === 8'hC5, "T13_ALT_RX",
                         "ENABLE_LOOPBACK=0 RX failed or picked up TX instead of rx_serial_in");
            end
          end
        end
      join
      check_cond(saw_alt_rx, "T13_ALT_VALID", "460800 RX valid missing");
      cov_alt_param_frames++;

      // Test u_top_12m (12.5 MHz / 115200 / ENABLE_LOOPBACK=1)
      @(negedge clk_12m5);
      c12_tx_data  = 8'h8D;
      c12_tx_valid = 1'b1;
      @(posedge clk_12m5);
      #1ns;
      c12_tx_valid = 1'b0;
      for (int w = 0; w < 1400; w++) begin
        @(posedge clk_12m5);
        #1ns;
        if (c12_rx_valid) begin
          saw_c12_rx = 1'b1;
          check_cond(c12_rx_data === 8'h8D, "T13_12M5_LB", "12.5 MHz loopback mismatch");
        end
      end
      check_cond(saw_c12_rx, "T13_12M5_VALID", "12.5 MHz loopback valid missing");
      cov_alt_param_frames++;
    end

    // -----------------------------------------------------------------------
    // Final Coverage & PASS/FAIL Summary
    // -----------------------------------------------------------------------
    check_cond(cov_bits_seen_0 === 8'hFF, "COV_BITS0", "Not all 8 bit positions observed at 0");
    check_cond(cov_bits_seen_1 === 8'hFF, "COV_BITS1", "Not all 8 bit positions observed at 1");

    $display("============================================================");
    $display("UART Verification Summary");
    $display("  Checks Passed      : %0d", pass_count);
    $display("  Checks Failed      : %0d", err_count);
    $display("  TX Frames Verified : %0d", cov_tx_frames);
    $display("  RX Frames Verified : %0d", cov_rx_frames);
    $display("  Loopback Frames    : %0d", cov_loopback_frames);
    $display("  Full-Duplex Ops    : %0d", cov_fullduplex_ops);
    $display("  Alt-Param Frames   : %0d", cov_alt_param_frames);
    $display("  Framing Errors     : %0d", cov_rx_ferr);
    $display("  Glitches Rejected  : %0d", cov_rx_glitches);
    $display("  Mid-Frame Resets   : %0d", cov_reset_mid_frame);
    $display("  Bit Toggle 0/1     : 0x%02x / 0x%02x", cov_bits_seen_0, cov_bits_seen_1);
    $display("============================================================");

    if (err_count != 0) begin
      $fatal(1, "UART_TB FAILED with %0d error(s)", err_count);
    end else begin
      $display("UART_TB PASSED");
      $finish;
    end
  end

endmodule
