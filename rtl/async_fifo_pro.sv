//-----------------------------------------------------------------------------
// Module: async_fifo_pro
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module async_fifo_pro #(
    parameter int DATA_WIDTH         = 32,
    parameter int ADDR_WIDTH         = 4,
    parameter int SYNC_STAGES        = 2,
    parameter int ALMOST_FULL_THRESH = (1 << ADDR_WIDTH) - 2,
    parameter int ALMOST_EMPTY_THRESH= 2,
    localparam int DEPTH             = 1 << ADDR_WIDTH,
    localparam int PTR_WIDTH         = ADDR_WIDTH + 1
)(
    // Write Domain
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  wfull,
    output logic                  almost_full,
    output logic [PTR_WIDTH-1:0]  w_occupancy,

    // Read Domain
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rempty,
    output logic                  almost_empty,
    output logic [PTR_WIDTH-1:0]  r_occupancy
);

    // Internal Gray pointers & Memory addresses
    logic [PTR_WIDTH-1:0]  wptr;
    logic [PTR_WIDTH-1:0]  rptr;
    logic [PTR_WIDTH-1:0]  wptr_sync;
    logic [PTR_WIDTH-1:0]  rptr_sync;
    logic [ADDR_WIDTH-1:0] waddr;
    logic [ADDR_WIDTH-1:0] raddr;

    // 1. Dual-Port Memory Buffer
    async_fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_mem (
        .wclk (wclk),
        .winc (winc),
        .wfull(wfull),
        .waddr(waddr),
        .wdata(wdata),
        .raddr(raddr),
        .rdata(rdata)
    );

    // 2. CDC Synchronizer: Read Pointer -> Write Domain (r2w)
    cdc_sync #(
        .WIDTH (PTR_WIDTH),
        .STAGES(SYNC_STAGES)
    ) u_sync_r2w (
        .clk  (wclk),
        .rst_n(wrst_n),
        .din  (rptr),
        .dout (rptr_sync)
    );

    // 3. CDC Synchronizer: Write Pointer -> Read Domain (w2r)
    cdc_sync #(
        .WIDTH (PTR_WIDTH),
        .STAGES(SYNC_STAGES)
    ) u_sync_w2r (
        .clk  (rclk),
        .rst_n(rrst_n),
        .din  (wptr),
        .dout (wptr_sync)
    );

    // 4. Write Pointer & Full Flag Controller
    wptr_full_ctrl #(
        .ADDR_WIDTH        (ADDR_WIDTH),
        .ALMOST_FULL_THRESH(ALMOST_FULL_THRESH)
    ) u_wptr_full (
        .wclk       (wclk),
        .wrst_n     (wrst_n),
        .winc       (winc),
        .rptr_sync  (rptr_sync),
        .wfull      (wfull),
        .almost_full(almost_full),
        .wptr       (wptr),
        .waddr      (waddr),
        .w_occupancy(w_occupancy)
    );

    // 5. Read Pointer & Empty Flag Controller
    rptr_empty_ctrl #(
        .ADDR_WIDTH         (ADDR_WIDTH),
        .ALMOST_EMPTY_THRESH(ALMOST_EMPTY_THRESH)
    ) u_rptr_empty (
        .rclk        (rclk),
        .rrst_n      (rrst_n),
        .rinc        (rinc),
        .wptr_sync   (wptr_sync),
        .rempty      (rempty),
        .almost_empty(almost_empty),
        .rptr        (rptr),
        .raddr       (raddr),
        .r_occupancy (r_occupancy)
    );

endmodule
