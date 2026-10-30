//-----------------------------------------------------------------------------
// Testbench: tb_fifo2
// asynchronous testbench for FIFO Style #2
// Features:
// - Asynchronous, non-integer ratio clocks (wclk = 100MHz, rclk = 75.2MHz)
// - Scoreboard queue for verifying First-In-First-Out data integrity
// - Burst write to full, burst read to empty
// - Concurrent random writes and reads
// - VCD waveform generation for GTKWave
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_fifo2;

    localparam int DATASIZE = 8;
    localparam int ADDRSIZE = 4;
    localparam int DEPTH    = 1 << ADDRSIZE; // 16 entries

    // Clocks and Resets
    logic                wclk = 0;
    logic                wrst_n = 0;
    logic                winc = 0;
    logic [DATASIZE-1:0] wdata = '0;
    logic                wfull;

    logic                rclk = 0;
    logic                rrst_n = 0;
    logic                rinc = 0;
    logic [DATASIZE-1:0] rdata;
    logic                rempty;

    // Testbench Scoreboard & stats
    logic [DATASIZE-1:0] expected_queue[$];
    logic [DATASIZE-1:0] test_val;
    int write_count = 0;
    int read_count  = 0;
    int error_count = 0;

    // Clock Generation (Asynchronous frequencies)
    // wclk: 100 MHz (Period = 10.0 ns)
    always #5.000 wclk = ~wclk;

    // rclk: ~75.2 MHz (Period = 13.3 ns)
    always #6.650 rclk = ~rclk;

    // DUT Instantiation
    fifo2_top #(
        .DATASIZE(DATASIZE),
        .ADDRSIZE(ADDRSIZE)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty)
    );

    // Protocol & Safety Assertions
    fifo_assertions #(
        .DATASIZE(DATASIZE),
        .ADDRSIZE(ADDRSIZE)
    ) u_assertions (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wfull  (wfull),
        .wptr   (dut.wptr),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rempty (rempty),
        .rptr   (dut.rptr)
    );

    // Write Task (Single Word)
    task automatic write_word(input [DATASIZE-1:0] data);
        @(posedge wclk);
        while (wfull) begin
            @(posedge wclk); // wait until not full
        end
        winc  <= 1'b1;
        wdata <= data;
        expected_queue.push_back(data);
        write_count++;
        @(posedge wclk);
        winc  <= 1'b0;
        wdata <= '0;
    endtask

    // Read Task (Single Word)
    task automatic read_word();
        logic [DATASIZE-1:0] exp_data;
        @(posedge rclk);
        while (rempty) begin
            @(posedge rclk); // wait until not empty
        end
        // With combinational read, rdata is valid at current pointer
        exp_data = expected_queue.pop_front();
        if (rdata !== exp_data) begin
            $error("[TB-DATA-ERROR] Data mismatch! Read %h, Expected %h at time %0t",
                   rdata, exp_data, $time);
            error_count++;
        end else begin
            $display("[TB-READ-OK] Read %h (matches expected) at time %0t", rdata, $time);
        end
        read_count++;
        rinc <= 1'b1;
        @(posedge rclk);
        rinc <= 1'b0;
    endtask

    // Main Test Stimulus
    initial begin

        $display("\n=======================================================");
        $display("       Starting Async FIFO (Style #2) Verification      ");
        $display("=======================================================\n");

        // Enable waveform dump
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_fifo2);

        // ----------------------------------------------------
        // Step 1: System Reset
        // ----------------------------------------------------
        $display("[Step 1] Applying system reset...");
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        winc   = 1'b0;
        rinc   = 1'b0;
        #50;
        @(posedge wclk); wrst_n = 1'b1;
        @(posedge rclk); rrst_n = 1'b1;
        #30;

        // Check reset state
        if (rempty !== 1'b1 || wfull !== 1'b0) begin
            $error("[TB-RESET-ERROR] Incorrect reset state! rempty=%b (exp 1), wfull=%b (exp 0)",
                   rempty, wfull);
            error_count++;
        end else begin
            $display("[TB-RESET-OK] Reset successful: rempty=1, wfull=0");
        end

        // ----------------------------------------------------
        // Step 2: Single Write and Single Read
        // ----------------------------------------------------
        $display("\n[Step 2] Testing single write & read...");
        write_word(8'hA5);
        // Wait for empty flag deassertion across clock domains
        repeat (4) @(posedge rclk);
        read_word();
        repeat (4) @(posedge rclk);

        if (rempty !== 1'b1) begin
            $error("[TB-FLAG-ERROR] rempty did not reassert after reading sole element!");
            error_count++;
        end

        // ----------------------------------------------------
        // Step 3: Burst Write to Full
        // ----------------------------------------------------
        $display("\n[Step 3] Burst writing %0d elements until FULL...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            write_word(8'h10 + i[7:0]);
        end

        // Give 1 wclk edge for full flag preset to register
        @(posedge wclk);
        if (wfull !== 1'b1) begin
            $error("[TB-FLAG-ERROR] Expected wfull=1 after %0d writes, but wfull=%b", DEPTH, wfull);
            error_count++;
        end else begin
            $display("[TB-FULL-OK] FIFO reached FULL condition successfully (wfull=1).");
        end

        // ----------------------------------------------------
        // Step 4: Burst Read to Empty
        // ----------------------------------------------------
        $display("\n[Step 4] Burst reading %0d elements until EMPTY...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            read_word();
        end

        // Wait for empty flag preset to register in read domain
        repeat (2) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[TB-FLAG-ERROR] Expected rempty=1 after draining FIFO, but rempty=%b", rempty);
            error_count++;
        end else begin
            $display("[TB-EMPTY-OK] FIFO reached EMPTY condition successfully (rempty=1).");
        end

        // ----------------------------------------------------
        // Step 5: Concurrent Asynchronous Writes and Reads
        // ----------------------------------------------------
        $display("\n[Step 5] Testing concurrent asynchronous writes and reads...");
        fork
            // Write thread: writes 30 random items
            begin : write_thread
                for (int i = 0; i < 30; i++) begin
                    test_val = $random;
                    write_word(test_val);
                    // Add slight random delay between writes
                    repeat ($urandom_range(0, 2)) @(posedge wclk);
                end
            end

            // Read thread: reads 30 items
            begin : read_thread
                for (int j = 0; j < 30; j++) begin
                    read_word();
                    // Add slight random delay between reads
                    repeat ($urandom_range(0, 3)) @(posedge rclk);
                end
            end
        join

        #100;

       
        $display("\n=======================================================");
        $display("                 VERIFICATION SUMMARY                  ");
        $display("=======================================================");
        $display(" Total Writes: %0d", write_count);
        $display(" Total Reads : %0d", read_count);
        $display(" Error Count : %0d", error_count);
        if (error_count == 0 && expected_queue.size() == 0) begin
            $display(" RESULT: >>> ALL TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
            $display(" RESULT: >>> TEST FAILED WITH %0d ERRORS! <<<", error_count);
        end
        $display("=======================================================\n");

        $finish;
    end

endmodule
