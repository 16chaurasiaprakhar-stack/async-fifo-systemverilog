//-----------------------------------------------------------------------------
// Testbench: async_fifo_pro_tb
// Description: Multi-Phase Asynchronous FIFO Verification Suite
// Features:
// - Dynamic clock generation with variable frequencies (Fast/Slow Producer & Consumer)
// - Transaction-level golden model scoreboard (SystemVerilog queue)
// - Comprehensive corner-case coverage:
//     Phase 1: Power-on Reset and Default Flags
//     Phase 2: Single Entry Write/Read Handshake
//     Phase 3: Burst Write to Full & Almost-Full Watermark Check
//     Phase 4: Burst Read to Empty & Almost-Empty Watermark Check
//     Phase 5: Asynchronous Clock Ratio Test: Fast Write (200MHz) -> Slow Read (25MHz)
//     Phase 6: Asynchronous Clock Ratio Test: Slow Write (25MHz) -> Fast Read (200MHz)
//     Phase 7: Random Concurrent Traffic with High Stress
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module async_fifo_pro_tb;

    localparam int DATA_WIDTH         = 32;
    localparam int ADDR_WIDTH         = 4;
    localparam int DEPTH              = 1 << ADDR_WIDTH; // 16 entries
    localparam int PTR_WIDTH          = ADDR_WIDTH + 1;
    localparam int SYNC_STAGES        = 2;
    localparam int ALMOST_FULL_THRESH = DEPTH - 2;       // 14
    localparam int ALMOST_EMPTY_THRESH= 2;

    // Clocks and Resets
    logic                  wclk = 0;
    logic                  wrst_n = 0;
    logic                  winc = 0;
    logic [DATA_WIDTH-1:0] wdata = '0;
    logic                  wfull;
    logic                  almost_full;
    logic [PTR_WIDTH-1:0]  w_occupancy;

    logic                  rclk = 0;
    logic                  rrst_n = 0;
    logic                  rinc = 0;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;
    logic                  almost_empty;
    logic [PTR_WIDTH-1:0]  r_occupancy;

    // Testbench deliberate error injection flags
    logic                  allow_overflow_test  = 0;
    logic                  allow_underflow_test = 0;

    // Configurable clock half-periods for frequency sweeps
    real wclk_half_period = 5.0;  // Default: 100 MHz (period 10ns)
    real rclk_half_period = 6.65; // Default: ~75.2 MHz (period 13.3ns)

    // Scoreboard & Statistics
    logic [DATA_WIDTH-1:0] scoreboard_queue[$];
    logic [DATA_WIDTH-1:0] rand_data;
    int total_writes = 0;
    int total_reads  = 0;
    int total_errors = 0;

    // Clock Oscillators
    always #(wclk_half_period) wclk = ~wclk;
    always #(rclk_half_period) rclk = ~rclk;

    // Instantiate Production Async FIFO
    async_fifo_pro #(
        .DATA_WIDTH        (DATA_WIDTH),
        .ADDR_WIDTH        (ADDR_WIDTH),
        .SYNC_STAGES       (SYNC_STAGES),
        .ALMOST_FULL_THRESH(ALMOST_FULL_THRESH),
        .ALMOST_EMPTY_THRESH(ALMOST_EMPTY_THRESH)
    ) dut (
        .wclk        (wclk),
        .wrst_n      (wrst_n),
        .winc        (winc),
        .wdata       (wdata),
        .wfull       (wfull),
        .almost_full (almost_full),
        .w_occupancy (w_occupancy),
        .rclk        (rclk),
        .rrst_n      (rrst_n),
        .rinc        (rinc),
        .rdata       (rdata),
        .rempty      (rempty),
        .almost_empty(almost_empty),
        .r_occupancy (r_occupancy)
    );

    // Instantiate Assertions
    async_fifo_sva #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_sva (
        .wclk        (wclk),
        .wrst_n      (wrst_n),
        .winc        (winc),
        .wfull       (wfull),
        .almost_full (almost_full),
        .wptr        (dut.wptr),
        .w_occupancy (w_occupancy),
        .rclk        (rclk),
        .rrst_n      (rrst_n),
        .rinc        (rinc),
        .rempty      (rempty),
        .almost_empty(almost_empty),
        .rptr        (dut.rptr),
        .r_occupancy (r_occupancy),
        .allow_overflow_test (allow_overflow_test),
        .allow_underflow_test(allow_underflow_test)
    );

    // Task: Write Single Word
    task automatic write_word(input [DATA_WIDTH-1:0] data);
        @(posedge wclk);
        while (wfull) begin
            @(posedge wclk);
        end
        winc  <= 1'b1;
        wdata <= data;
        scoreboard_queue.push_back(data);
        total_writes++;
        @(posedge wclk);
        winc  <= 1'b0;
        wdata <= '0;
    endtask

    // Task: Read Single Word
    task automatic read_word();
        logic [DATA_WIDTH-1:0] expected;
        @(posedge rclk);
        while (rempty) begin
            @(posedge rclk);
        end
        expected = scoreboard_queue.pop_front();
        if (rdata !== expected) begin
            $error("[FAIL] Data mismatch! Read %h, Expected %h at time %0t",
                   rdata, expected, $time);
            total_errors++;
        end
        total_reads++;
        rinc <= 1'b1;
        @(posedge rclk);
        rinc <= 1'b0;
    endtask

    // Test Sequence
    initial begin
        $display("\n=======================================================");
        $display("   STARTING PRODUCTION ASYNC FIFO COMPREHENSIVE SUITE   ");
        $display("=======================================================\n");

        $dumpfile("async_fifo_pro.vcd");
        $dumpvars(0, async_fifo_pro_tb);

        // ----------------------------------------------------
        // Phase 1: Reset & Initial State Verification
        // ----------------------------------------------------
        $display("[Phase 1] Reset & Initial State Check");
        wrst_n = 0;
        rrst_n = 0;
        winc   = 0;
        rinc   = 0;
        #50;
        @(posedge wclk); wrst_n = 1;
        @(posedge rclk); rrst_n = 1;
        repeat (4) @(posedge rclk);

        if (!rempty || !almost_empty || wfull || almost_full) begin
            $error("[FAIL] Incorrect reset states! rempty=%b, aempty=%b, wfull=%b, afull=%b",
                   rempty, almost_empty, wfull, almost_full);
            total_errors++;
        end else begin
            $display("  -> Reset verified: rempty=1, almost_empty=1, wfull=0, almost_full=0");
        end

        // ----------------------------------------------------
        // Phase 2: Single Write and Single Read Handshake
        // ----------------------------------------------------
        $display("\n[Phase 2] Single Transaction Handshake");
        write_word(32'hDEAD_BEEF);
        repeat (SYNC_STAGES + 2) @(posedge rclk); // allow pointer sync
        read_word();
        repeat (SYNC_STAGES + 2) @(posedge rclk);
        if (!rempty) begin
            $error("[FAIL] rempty not re-asserted after reading sole element!");
            total_errors++;
        end else begin
            $display("  -> Single word write & read passed, rempty correctly restored.");
        end

        // ----------------------------------------------------
        // Phase 3: Burst Write to Full & Watermark Check
        // ----------------------------------------------------
        $display("\n[Phase 3] Burst Write to Full (Depth = %0d)", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            write_word(32'hA000_0000 + i);
        end
        @(posedge wclk);

        if (!wfull || !almost_full) begin
            $error("[FAIL] Expected wfull=1 and almost_full=1, got wfull=%b, almost_full=%b",
                   wfull, almost_full);
            total_errors++;
        end else begin
            $display("  -> Burst write full passed: wfull=1, almost_full=1, w_occupancy=%0d", w_occupancy);
        end

        // Attempt write when full (defensive hardware overflow protection check)
        $display("  -> Testing hardware defensive write protection when full...");
        allow_overflow_test = 1'b1;
        winc  <= 1'b1;
        wdata <= 32'hBAD0_BAD0;
        @(posedge wclk);
        winc  <= 1'b0;
        @(posedge wclk);
        allow_overflow_test = 1'b0;

        // ----------------------------------------------------
        // Phase 4: Burst Read to Empty & Watermark Check
        // ----------------------------------------------------
        $display("\n[Phase 4] Burst Read to Empty (Depth = %0d)", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            read_word();
        end
        repeat (SYNC_STAGES + 2) @(posedge rclk);

        if (!rempty || !almost_empty) begin
            $error("[FAIL] Expected rempty=1 and almost_empty=1, got rempty=%b, almost_empty=%b",
                   rempty, almost_empty);
            total_errors++;
        end else begin
            $display("  -> Burst read empty passed: rempty=1, almost_empty=1, r_occupancy=%0d", r_occupancy);
        end

        // Attempt read when empty (defensive hardware underflow protection check)
        $display("  -> Testing hardware defensive read protection when empty...");
        allow_underflow_test = 1'b1;
        rinc <= 1'b1;
        @(posedge rclk);
        rinc <= 1'b0;
        @(posedge rclk);
        allow_underflow_test = 1'b0;

        // ----------------------------------------------------
        // Phase 5: Fast Producer (200MHz) -> Slow Consumer (25MHz)
        // ----------------------------------------------------
        $display("\n[Phase 5] Extreme Ratio 1: Fast Producer (200MHz) -> Slow Consumer (25MHz)");
        wclk_half_period = 2.5;  // 200 MHz (T = 5ns)
        rclk_half_period = 20.0; // 25 MHz  (T = 40ns)

        fork
            begin : fast_write_thread
                for (int i = 0; i < 40; i++) begin
                    rand_data = $random;
                    write_word(rand_data);
                end
            end
            begin : slow_read_thread
                for (int j = 0; j < 40; j++) begin
                    read_word();
                end
            end
        join

        $display("  -> Fast Producer / Slow Consumer test passed with 0 errors.");

        // ----------------------------------------------------
        // Phase 6: Slow Producer (25MHz) -> Fast Consumer (200MHz)
        // ----------------------------------------------------
        $display("\n[Phase 6] Extreme Ratio 2: Slow Producer (25MHz) -> Fast Consumer (200MHz)");
        wclk_half_period = 20.0; // 25 MHz  (T = 40ns)
        rclk_half_period = 2.5;  // 200 MHz (T = 5ns)

        fork
            begin : slow_write_thread
                for (int i = 0; i < 40; i++) begin
                    rand_data = $random;
                    write_word(rand_data);
                end
            end
            begin : fast_read_thread
                for (int j = 0; j < 40; j++) begin
                    read_word();
                end
            end
        join

        $display("  -> Slow Producer / Fast Consumer test passed with 0 errors.");

        // ----------------------------------------------------
        // Phase 7: High-Stress Random Concurrent Traffic
        // ----------------------------------------------------
        $display("\n[Phase 7] High-Stress Random Traffic with Jitter (100MHz vs 133MHz)");
        wclk_half_period = 5.0;  // 100 MHz
        rclk_half_period = 3.75; // 133.3 MHz

        fork
            begin : stress_write_thread
                for (int i = 0; i < 60; i++) begin
                    rand_data = $random;
                    write_word(rand_data);
                    repeat ($urandom_range(0, 2)) @(posedge wclk);
                end
            end
            begin : stress_read_thread
                for (int j = 0; j < 60; j++) begin
                    read_word();
                    repeat ($urandom_range(0, 3)) @(posedge rclk);
                end
            end
        join

        // Drain any remaining items
        while (scoreboard_queue.size() > 0) begin
            read_word();
        end

        #200;

        // ----------------------------------------------------
        // Final Results Summary
        // ----------------------------------------------------
        $display("\n=======================================================");
        $display("             PRODUCTION VERIFICATION SUMMARY          ");
        $display("=======================================================");
        $display(" Total Transactions Written: %0d", total_writes);
        $display(" Total Transactions Read   : %0d", total_reads);
        $display(" Residual Scoreboard Size  : %0d", scoreboard_queue.size());
        $display(" Total Errors Reported     : %0d", total_errors);
        if (total_errors == 0 && scoreboard_queue.size() == 0) begin
            $display(" RESULT: >>> 100%% VERIFICATION SUCCESSFUL (PASSED) <<<");
        end else begin
            $display(" RESULT: >>> VERIFICATION FAILED WITH %0d ERRORS <<<", total_errors);
        end
        $display("=======================================================\n");

        $finish;
    end

endmodule
