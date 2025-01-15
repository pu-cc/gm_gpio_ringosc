`timescale 1ns / 1ps

module osc (
    inout osc_io,
    input osc_rst,
    input osc_halt,
    output reg [31:0] osc_counter
);
    wire io_lb;

    CC_IOBUF #(
        .DRIVE("3"),         // "3", "6", "9" or "12" mA
        .SLEW("SLOW"),       // "SLOW" or "FAST"
        .PULLUP(0),          // 0: disable, 1: enable
        .PULLDOWN(0),        // 0: disable, 1: enable
        .KEEPER(0),          // 0: disable, 1: enable
        .SCHMITT_TRIGGER(0), // 0: disable, 1: enable
        .DELAY_IBF(4'd0),    // input delay: 0..15
        .DELAY_OBF(4'd0),    // input delay: 0..15
        .FF_IBF(1'b0),       // 0: disable, 1: enable
        .FF_OBF(1'b0)        // 0: disable, 1: enable
    ) iobuf_inst (
        .A(~io_lb),
        .T(osc_halt), // 0: output, 1: input
        .Y(io_lb),
        .IO(osc_io)
    );

    initial osc_counter = 0;

    // ringosc counter
    always @(posedge io_lb or posedge osc_rst)
    begin
        if (osc_rst == 1) begin
            osc_counter <= 0;
        end
        else begin
            osc_counter <= osc_counter + 1'b1;
        end
    end
endmodule
