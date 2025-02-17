`timescale 1ns / 1ps

/**
 * i2c/bmp280.v
 *
 * BMP280 I2C temerpature sensor interface module.
 *
 * This module implements an I2C interface controller to setup and read the
 * status and temperature registers of a BMP280 temperature/pressure sensor.
 *
 * Copyright (C) 2025 Cologne Chip AG <support@colognechip.com>
 * Authors: Patrick Urban
 */

module bmp280 #(
    parameter [2:0] osrs_p = 3'b000, // press: skipped
    parameter [2:0] osrs_t = 3'b101, // temp:  oversampling x16
    parameter [1:0] mode = 2'b11 // normal
)(
    input         clk,
    input         rstn,
    input         start,
    output reg    data_valid,
    output [19:0] temperature,
    output [19:0] pressure,

    // interface to I2C controller
    input              i2c_strobe,
    output reg         i2c_enable,  // one-cycle pulse to start a transaction
    output reg [7:0]   i2c_reg_addr,
    output reg [4:0]   i2c_reg_len,
    input      [7:0]   i2c_reg_rddata,
    output reg [7:0]   i2c_reg_wrdata,
    output reg         i2c_reg_rdwr, // 0 = write, 1 = read
    input              i2c_done,
    input              i2c_rd_done,
    input              i2c_ack
);

    localparam S_RESET           = 0;
    localparam S_INIT            = 1;
    localparam S_IDLE            = 2;

    localparam S_WRITE_CALIB_PTR = 3; // 0xA1..0x88
    localparam S_READ_CALIB      = 4;
    localparam S_READ_CALIB_WAIT = 5;

    localparam S_WRITE_TEMP_PTR  = 6;
    localparam S_READ_TEMP       = 7;
    localparam S_READ_TEMP_WAIT  = 8;

    localparam S_DONE            = 9;

    reg [3:0] state = '0;

    // Temporary registers to hold registers
    reg [23:0] temp, press;
    reg [(26*8)-1:0] calib;

    assign temperature = temp[23:4];
    assign pressure = press[23:4];

    reg [23:0] test;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state          <= S_RESET;
            i2c_enable     <= 1'b0;
            data_valid     <= 1'b0;
            temp           <= 24'h0;
            press          <= 24'h0;
            i2c_reg_addr   <= 8'h00;
            i2c_reg_rdwr   <= 1'b0;
            i2c_reg_wrdata <= '0;
            i2c_reg_len    <= '0;
        end
        else if (i2c_strobe) begin
            case (state)
                S_RESET: begin
                    data_valid     <= 1'b0;
                    i2c_reg_rdwr   <= 1'b0;
                    i2c_reg_addr   <= 8'hF3; // reset register
                    i2c_reg_wrdata <= 8'hB6; // reset trigger
                    i2c_enable     <= 1'b1;
                    i2c_reg_len    <= 3;
                    state          <= S_INIT;
                end
                S_INIT: begin
                    data_valid <= 1'b0;
                    if (i2c_done) begin
                        i2c_reg_rdwr   <= 1'b0;
                        i2c_reg_addr   <= 8'hF4; // config ctrl_meas
                        i2c_reg_wrdata <= {osrs_t[2:0], osrs_p[2:0], mode[1:0]};
                        i2c_enable     <= 1'b1;
                        i2c_reg_len    <= 3;
                        state          <= S_WRITE_CALIB_PTR;
                    end
                end

                S_IDLE: begin
                    data_valid <= 1'b0;
                    i2c_enable <= 1'b0;
                    if (start) begin
                        state  <= S_WRITE_TEMP_PTR;
                    end
                end

                S_WRITE_CALIB_PTR: begin
                    data_valid <= 1'b0;
                    if (i2c_done) begin
                        i2c_reg_rdwr <= 1'b0;
                        i2c_reg_addr <= 8'h88;
                        i2c_enable   <= 1'b1;
                        i2c_reg_len  <= 2;
                        state        <= S_READ_CALIB;
                    end
                end

                S_READ_CALIB: begin
                    i2c_enable <= 1'b0;
                    if (i2c_done) begin
                        i2c_reg_rdwr <= 1'b1;
                        i2c_enable   <= 1'b1;
                        i2c_reg_len  <= 1+26;
                        state        <= S_READ_CALIB_WAIT;
                    end
                end

                S_READ_CALIB_WAIT: begin
                    i2c_enable <= 1'b0;
                    if (i2c_rd_done) begin
                        calib <= {calib[(25*8)-1:0], i2c_reg_rddata};
                    end
                    if (i2c_done) begin
                        state  <= S_DONE;
                    end
                end

                S_WRITE_TEMP_PTR: begin
                    data_valid <= 1'b0;
                    if (i2c_done || start) begin
                        i2c_reg_rdwr <= 1'b0;
                        i2c_reg_addr <= 8'hFA;
                        i2c_enable   <= 1'b1;
                        i2c_reg_len  <= 2;
                        state        <= S_READ_TEMP;
                    end
                end

                S_READ_TEMP: begin
                    i2c_enable <= 1'b0;
                    if (i2c_done) begin
                        // Now initiate a read transaction.
                        // We assume the BMP280 auto-increments its internal pointer,
                        // so a series of read transactions will return 0xFA, 0xFB, 0xFC.
                        i2c_reg_rdwr <= 1'b1; // Read transaction
                        i2c_enable   <= 1'b1;
                        i2c_reg_len  <= 4;
                        state        <= S_READ_TEMP_WAIT;
                    end
                end

                S_READ_TEMP_WAIT: begin
                    i2c_enable <= 1'b0;
                    if (i2c_rd_done) begin
                        temp <= {temp[15:0], i2c_reg_rddata};
                    end
                    if (i2c_done) begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    // Wait here until 'start' is deasserted so we don't immediately
                    // begin another transaction.
                    data_valid  <= 1'b1;
                    if (!start)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
