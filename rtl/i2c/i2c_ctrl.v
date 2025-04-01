`timescale 1ns / 1ps

/**
 * i2c/i2c_ctrl.v
 *
 * Copyright (C) 2025 Cologne Chip AG <support@colognechip.com>
 * Authors: Patrick Urban
 */

module i2c_ctrl (
    input  wire        clk,
    input  wire        i2c_strobe,
    input  wire        arst_n,

    input  wire        i2c_enable,
    input  wire  [6:0] i2c_addr,
    input  wire        reg_rdwr,
    input  wire  [7:0] reg_addr,
    input  wire  [4:0] reg_len,
    input  wire  [7:0] reg_wrdata,
    output wire  [7:0] reg_rddata,
    output reg         reg_done,
    output reg         i2c_rd_done,
    output reg         i2c_ack,

    output wire        scl_oe,
    output reg         scl_do,
    input  wire        scl_di,
    output wire        sda_oe,
    output reg         sda_do,
    input  wire        sda_di
);

    localparam
        //          ADnn
        S_IDLE = 4'b0000,
        S_STRT = 4'b0001,
        S_HOLD = 4'b0010,
        S_DAT1 = 4'b0100,
        S_DAT2 = 4'b0101,
        S_DAT3 = 4'b0110,
        S_DAT4 = 4'b0111,
        S_ACK1 = 4'b1000,
        S_ACK2 = 4'b1001,
        S_ACK3 = 4'b1010,
        S_ACK4 = 4'b1011,
        S_STOP = 4'b0011;

    reg [3:0] next_state, state = 0;

    reg [3:0] bit_cnt;
    reg [4:0] byte_cnt;

    reg  [7:0] id;
    reg [15:0] addr;
    reg  [7:0] data;
    //reg scl_do, sda_do;
    reg rdwr;

    assign scl_oe = 1'b1;
    assign sda_oe = ((rdwr && byte_cnt >= 1) && (state[2] == 1'b1)) || (!rdwr && (state[3] == 1'b1)) ? 1'b0 : 1'b1;

    reg [23:0] tx_data;
    reg  [7:0] rx_data;

    assign reg_rddata = rx_data;

    // State machine for i2c control
    always @(posedge clk or negedge arst_n) begin
        if (arst_n == 1'b0) begin
            state <= S_IDLE;
            reg_done <= 1'b0;
            bit_cnt <= 4'd0;
            byte_cnt <= 3'd0;
            scl_do = 1'b1;
            sda_do = 1'b1;
            i2c_ack <= 1'b0;
            i2c_rd_done <= 0;
        end
        else if (i2c_strobe) begin
            case (state)
                S_IDLE: begin
                    scl_do = 1'b1;
                    sda_do = 1'b1;
                    reg_done <= 1'b0;
                    if (i2c_enable) begin
                        byte_cnt <= '0;
                        state <= S_STRT;
                        i2c_ack <= 1'b0;
                        rdwr <= reg_rdwr;
                    end
                end
                S_STRT: begin
                    tx_data <= {i2c_addr, reg_rdwr, reg_addr, reg_wrdata};
                    scl_do <= 1'b1;
                    sda_do <= 1'b0;
                    state <= S_HOLD;
                end
                S_HOLD: begin
                    scl_do <= 1'b0;
                    sda_do <= 1'b0;
                    bit_cnt <= '0;
                    state <= S_DAT1;
                end
                S_DAT1: begin
                    i2c_rd_done <= 0;
                    scl_do <= 1'b0;
                    sda_do <= tx_data[23];
                    if (rdwr && byte_cnt >= 1)
                        rx_data <= {rx_data[6:0], sda_di};
                    else
                        tx_data <= {tx_data[22:0], tx_data[23]};
                    state <= S_DAT2;
                end
                S_DAT2: begin
                    scl_do <= 1'b1;
                    state <= S_DAT3;
                end
                S_DAT3: begin
                    state <= S_DAT4;
                end
                S_DAT4: begin
                    scl_do <= 1'b0;
                    if (bit_cnt < 7) begin
                        bit_cnt <= bit_cnt + 1'b1;
                        state <= S_DAT1;
                    end
                    else begin
                        byte_cnt <= byte_cnt + 1'b1;
                        state <= S_ACK1;
                        if (rdwr) begin
                            sda_do <= (byte_cnt == reg_len-1); // send (N)ACK
                        end
                    end
                end
                S_ACK1: begin
                    scl_do <= 1'b0;
                    state <= S_ACK2;
                end
                S_ACK2: begin
                    scl_do <= 1'b1;
                    state <= S_ACK3;
                end
                S_ACK3: begin
                    i2c_ack <= sda_di;
                    state <= S_ACK4;
                end
                S_ACK4: begin
                    scl_do <= 1'b0;
                    if (rdwr && (byte_cnt > 1))
                        i2c_rd_done <= 1'b1;
                    if (byte_cnt < (reg_len)) begin
                        bit_cnt <= '0;
                        state <= S_DAT1;
                    end
                    else begin
                        state <= S_STOP;
                    end
                end
                S_STOP: begin
                    i2c_rd_done <= 0;
                    scl_do <= 1'b1;
                    reg_done <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
   end
endmodule
