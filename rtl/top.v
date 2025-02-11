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
`ifdef ICARUS
    parameter REF_CLK = 100_000,
`else
    parameter REF_CLK = 10_000_000,
`endif
    parameter BAUD_RATE = 115200,
    parameter STP_SMPL = 30 // no. of samples until 1s osc halt
)(
    input  wire ref_clk,
    inout  wire osc_io_2v5,
    output wire const0_2v5, const1_2v5,
    inout  wire osc_io_3v6,
    output wire const0_3v6, const1_3v6,
    inout  wire i2c_sda_io,
    inout  wire i2c_scl_io,
    output wire bmp280_addr_sel_o,
    output wire bmp280_csb_const_o,
    output wire uart_tx,
    output wire uart_tx_done_n,
    output wire uart_tx_busy_n,
    output wire osc_halt
);
    assign {const0_3v6, const0_2v5} = 2'b00;
    assign {const1_3v6, const1_2v5} = 2'b11;

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
    reg [12*8-1:0] txd;

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
                txd <= {osc_counter_latch_3v6, osc_counter_latch_2v5, 8'h0, bmp280_temp, 4'h0};
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

    // i2c interface
    localparam C_BMP280_ADDR_SEL = 1'b0;
    assign bmp280_addr_sel_o = C_BMP280_ADDR_SEL;
    assign bmp280_csb_const_o = 1'b1;

    wire i2c_enable;
    wire [7:0] i2c_reg_addr;
    wire [4:0] i2c_reg_len;
    wire [7:0] i2c_reg_rddata;
    wire [7:0] i2c_reg_wrdata;
    wire i2c_reg_rdwr;
    wire i2c_reg_done;
    wire i2c_rd_done;
    wire i2c_ack;
    wire [19:0] bmp280_temp;
    reg bmp280_latch_req = 1'b0;

    wire i2c_scl_oe;
    wire i2c_scl_do;
    wire i2c_scl_di;
    wire i2c_sda_oe;
    wire i2c_sda_do;
    wire i2c_sda_di;

    // 100kHz strobe generator
    localparam NUM_CLK_I2C_STROBE = 25;
    reg [$clog2(NUM_CLK_I2C_STROBE)-1:0] cnt_strobe = 0;
    reg i2c_strobe = 0;

    always @(posedge ref_clk or posedge rst) begin
        if (rst == 1'b1) begin
            cnt_strobe <= 0;
            i2c_strobe <= 0;
        end
        else begin
            if (ref_counter == 0)
                bmp280_latch_req <= 1'b1;
            else if (i2c_enable)
                bmp280_latch_req <= 1'b0;
            if (cnt_strobe == (NUM_CLK_I2C_STROBE - 1)) begin
                cnt_strobe <= '0;
                i2c_strobe <= 1'b1;
            end
            else begin
                cnt_strobe <= cnt_strobe + 1;
                i2c_strobe <= 1'b0;
            end
        end
    end

    i2c_ctrl i2c_inst (
        .clk         (ref_clk),
        .i2c_strobe  (i2c_strobe), // 100kHz strobe
        .arst_n      (rstn),

        .i2c_enable  (i2c_enable),
        .i2c_addr    (C_BMP280_ADDR_SEL ? 7'h77 : 7'h76),
        .reg_rdwr    (i2c_reg_rdwr),
        .reg_addr    (i2c_reg_addr),
        .reg_wrdata  (i2c_reg_wrdata),
        .reg_rddata  (i2c_reg_rddata),
        .reg_len     (i2c_reg_len),
        .reg_done    (i2c_reg_done),
        .i2c_rd_done (i2c_rd_done),
        .i2c_ack     (i2c_ack),

        .scl_oe      (i2c_scl_oe),
        .scl_do      (i2c_scl_do),
        .scl_di      (i2c_scl_di),
        .sda_oe      (i2c_sda_oe),
        .sda_do      (i2c_sda_do),
        .sda_di      (i2c_sda_di)
    );

    // bmp280 temperature sensor state machine
    bmp280 bmp280_inst (
        .clk            (ref_clk),
        .rstn           (rstn),
        .start          (bmp280_latch_req),
        .temperature    (bmp280_temp),

        .i2c_strobe     (i2c_strobe),
        .i2c_enable     (i2c_enable),
        .i2c_reg_addr   (i2c_reg_addr),
        .i2c_reg_len    (i2c_reg_len),
        .i2c_reg_wrdata (i2c_reg_wrdata),
        .i2c_reg_rddata (i2c_reg_rddata),
        .i2c_reg_rdwr   (i2c_reg_rdwr),
        .i2c_rd_done    (i2c_rd_done),
        .i2c_done       (i2c_reg_done)
    );

    assign i2c_scl_io = i2c_scl_oe ? i2c_scl_do : 1'bz;
    assign i2c_scl_di = i2c_scl_io;
    assign i2c_sda_io = i2c_sda_oe ? i2c_sda_do : 1'bz;
    assign i2c_sda_di = i2c_sda_io;

    // uart interface
    wire uart_tx_done, uart_tx_busy;
    assign uart_tx_done_n = ~uart_tx_done;
    assign uart_tx_busy_n = ~uart_tx_busy;

    uart_tx #(
        .CLK_RATE(REF_CLK),
        .BAUD_RATE(BAUD_RATE),
        .WORD_LEN(8),
        .WORD_COUNT(12),
        .PARITY("L"),
        .STOP(1)
    ) tx_inst (
        .clk_i(ref_clk),
        .rst_i(rst),
        .tx_start_i(ref_counter == 0), // 1s
        .tx_data_i(txd),
        .tx_done_o(uart_tx_done),
        .tx_busy_o(uart_tx_busy),
        .tx_o(uart_tx)
    );

endmodule
