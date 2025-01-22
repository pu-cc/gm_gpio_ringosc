`timescale 1ns / 1ps

/**
 * top.v
 *
 * GPIO ring oscillator stress test.
 *
 * This module implements a GPIO-based ring oscillator for stress testing and
 * diagnostics. It measures oscillation frequencies on two voltage domains (2.5V
 * and 3.3V) and transmits the results via a UART interface. The module includes
 * sampling, halting mechanisms, and a configurable UART for data communication.
 *
 * Copyright (C) 2024, 2025 Cologne Chip AG <support@colognechip.com>
 * Authors: Patrick Urban
 */

module top #(
    parameter REF_CLK = 10000000,
    parameter BAUD_RATE = 115200,
    parameter STP_SMPL = 30 // no. of samples until 1s osc halt
)(
    input wire  ref_clk,
    inout wire  osc_io_2v5,
    inout wire  osc_io_3v6,
    output wire uart_tx,
    output wire uart_tx_done_n,
    output wire uart_tx_busy_n,
    output wire osc_halt
);
    // reset
    reg [5:0] rst_cnt = 0;
    wire rstn = &rst_cnt;
    wire rst = !rstn;

    always @(posedge ref_clk) begin
        rst_cnt <= rst_cnt + !rstn;
    end

    wire [31:0] osc_counter_2v5;
    wire [31:0] osc_counter_3v6;

    wire osc_latch_ack_2v5, osc_latch_ack_3v6;
    wire [31:0] osc_counter_latch_2v5, osc_counter_latch_3v6;

    osc osc_inst0 (
        .ref_clk(ref_clk),
        .osc_io(osc_io_2v5),
        .osc_rst(osc_rst),
        .osc_halt(osc_halt),
        .osc_latch_req(latch_req),
        .osc_latch_ack(osc_latch_ack_2v5),
        .osc_counter_latch(osc_counter_latch_2v5)
    );

    osc osc_inst1 (
        .ref_clk(ref_clk),
        .osc_io(osc_io_3v6),
        .osc_rst(osc_rst),
        .osc_halt(osc_halt),
        .osc_latch_req(latch_req),
        .osc_latch_ack(osc_latch_ack_3v6),
        .osc_counter_latch(osc_counter_latch_3v6)
    );

    reg [31:0] ref_counter = 0;
    reg latch_req = 0;
    reg done = 0;
    reg [2*32-1:0] txd;

    // generate sample latch request
    always @(posedge ref_clk or posedge rst)
    begin
        if (rst == 1'b1) begin
            ref_counter <= 0;
            latch_req <= 0;
            done <= 0;
            txd <= 0;
        end
        else begin
            if (!done) begin
                if (ref_counter < REF_CLK) begin
                    ref_counter <= ref_counter + 1'b1;
                end
                else begin
                    done <= 1;
                    latch_req <= 1'b1;
                end
            end
            // Transfer latched value
            if ((osc_latch_ack_2v5 & osc_latch_ack_3v6) || (done & osc_halt)) begin
                latch_req <= 1'b0;
                done <= 0;
                ref_counter <= 0;
                txd <= {osc_counter_latch_3v6, osc_counter_latch_2v5};
            end
        end
    end

    (* clkbuf_inhibit *)
    wire stp_clk = (ref_counter == REF_CLK);
    reg [$clog2(STP_SMPL)-1:0] stp_counter = 0;

    // stop counter: halt oscillator after `STP_SMPL` samples
    always @(posedge stp_clk)
    begin
        stp_counter <= stp_counter + 1'b1;
        if (stp_counter == STP_SMPL) begin
            stp_counter <= 0;
        end
    end

    assign osc_halt = (stp_counter == 0);
    wire osc_rst = (ref_counter == 0);

    // uart interface
    wire uart_tx_done, uart_tx_busy;
    assign uart_tx_done_n = ~uart_tx_done;
    assign uart_tx_busy_n = ~uart_tx_busy;

    uart_tx #(
        .CLK_RATE(REF_CLK),
        .BAUD_RATE(115200),
        .WORD_LEN(8),
        .WORD_COUNT(8),
        .PARITY("L"),
        .STOP(1)
    ) tx_inst (
        .clk_i(ref_clk),
        .rst_i(rst),
        .tx_start_i(ref_counter == 0),
        .tx_data_i(txd),
        .tx_done_o(uart_tx_done),
        .tx_busy_o(uart_tx_busy),
        .tx_o(uart_tx)
    );

endmodule
