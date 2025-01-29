`timescale 1ns / 1ps

module osc (
    input  ref_clk,
    inout  osc_io,
    input  osc_rst,
    input  osc_halt,
    input  osc_latch_req,
    output reg osc_latch_ack,
    output reg [31:0] osc_counter_latch
);
    (* clkbuf_inhibit *)
    wire osc_lb;

    CC_IOBUF #(
        .DRIVE("12"), // "3", "6", "9" or "12" mA
        .SLEW("SLOW") // "SLOW" or "FAST"
    ) iobuf_inst (
        .A(~osc_lb),
        .T(osc_halt | osc_rst), // 0: output, 1: input
        .Y(osc_lb),
        .IO(osc_io)
    );

    reg [31:0] osc_counter = 0;
    initial osc_counter_latch = 0;

    // ringosc counter
    always @(posedge osc_lb or posedge osc_rst)
    begin
        if (osc_rst == 1) begin
            osc_counter <= 0;
        end
        else if (!osc_latch_req) begin
            osc_counter <= osc_counter + 1'b1;
        end
    end

    // Synchronize latch_req to osc_lb domain
    reg latch_req_sync1 = 0, latch_req_sync2 = 0;
    always @(posedge osc_lb or posedge osc_rst) begin
        if (osc_rst == 1) begin
            latch_req_sync1 <= 0;
            latch_req_sync2 <= 0;
        end else begin
            latch_req_sync1 <= osc_latch_req;
            latch_req_sync2 <= latch_req_sync1;
        end
    end

    // Latch osc_counter when osc_latch_req is detected
    always @(posedge osc_lb or posedge osc_rst) begin
        if (osc_rst == 1) begin
            osc_counter_latch <= 0;
        end else if (latch_req_sync2) begin
            osc_counter_latch <= osc_counter;
        end
    end

    // Synchronize latch_ack back to ref_clk domain
    reg latch_ack_sync1 = 0;
    always @(posedge ref_clk or posedge osc_rst) begin
        if (osc_rst) begin
            latch_ack_sync1 <= 0;
            osc_latch_ack <= 0;
        end else begin
            latch_ack_sync1 <= latch_req_sync2;
            osc_latch_ack <= latch_ack_sync1;
        end
    end

endmodule
