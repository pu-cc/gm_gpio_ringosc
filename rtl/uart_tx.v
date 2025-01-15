`timescale 1ns/1ps

/**
 * uart_tx.v
 *
 * Naive multi-word UART transmitter.
 *
 * Copyright (C) 2024 Cologne Chip AG <support@colognechip.com>
 * Authors: Patrick Urban
 */

module uart_tx #(
    parameter CLK_RATE   = 10000000,
    parameter BAUD_RATE  = 115200,
    parameter WORD_LEN   = 8,   // 5, 6, 7, 8
    parameter WORD_COUNT = 1,
    parameter PARITY     = "L", // "L": none, "M": even, "N": odd
    parameter STOP       = 1    // 1, 2
)(
    input clk_i,
    input rst_i,
    input tx_start_i,
    input [(WORD_COUNT*WORD_LEN)-1:0] tx_data_i,
    output reg tx_done_o,
    output reg tx_busy_o,
    output reg tx_o
);

    localparam CLKDIV = CLK_RATE/BAUD_RATE;

    localparam S_IDLE   = 3'b000;
    localparam S_START  = 3'b001;
    localparam S_DATA   = 3'b010;
    localparam S_PARITY = 3'b011;
    localparam S_STOP   = 3'b100;

    reg [$clog2(CLKDIV)-1:0] div_counter_r;
    reg [2:0] tx_state_r;
    reg [WORD_LEN-1:0] tx_data_r;
    reg [3:0] tx_data_idx_r;
    reg tx_stop_r;
    reg [7:0] tx_word_count_r = 0;

    always @(posedge clk_i)
    begin
        if (rst_i) begin
            div_counter_r <= 0;
        end
        else if (div_counter_r < CLKDIV) begin
            div_counter_r <= div_counter_r + 1'b1;
        end
        else begin
            div_counter_r <= 0;
        end
    end

    always @(posedge clk_i)
    begin
        if (rst_i) begin
            tx_state_r <= S_IDLE;
            tx_data_idx_r <= 4'b0;
            tx_busy_o <= 0;
            tx_done_o <= 0;
            tx_word_count_r <= 0;
        end
        else begin
            case (tx_state_r)
                S_IDLE: begin
                    tx_o <= 1'b1; // idle
                    tx_done_o <= 1'b0;
                    tx_busy_o <= 1'b0;
                    tx_data_r <= {(WORD_LEN-1){1'b0}};
                    tx_data_idx_r <= 4'b0;
                    tx_stop_r <= 1'b0;
                    if (tx_start_i)
                        tx_word_count_r <= WORD_COUNT;
                    if (tx_word_count_r > 0) begin
                        tx_data_r <= tx_data_i >> WORD_LEN*(tx_word_count_r-1);
                        //tx_data_r <= tx_data_i[(WORD_LEN*tx_word_count_r)-1:(WORD_LEN*(tx_word_count_r-1))];
                        tx_state_r <= S_START;
                        tx_busy_o <= 1'b1;
                    end
                end
                S_START: begin
                    if (div_counter_r == 0) begin
                        tx_o <= 1'b0; // start
                        tx_state_r <= S_DATA;
                    end
                end
                S_DATA: begin
                    if (div_counter_r == 0) begin
                        if (tx_data_idx_r < WORD_LEN-1) begin
                            tx_data_idx_r <= tx_data_idx_r + 1'b1;
                        end
                        else begin
                            tx_state_r <= (PARITY == "L") ? S_STOP : S_PARITY;
                        end
                        tx_o <= tx_data_r[tx_data_idx_r];
                    end
                end
                S_PARITY: begin
                    if (div_counter_r == 0) begin
                        tx_o <= (PARITY == "M") ? ^tx_data_r : ~^tx_data_r;
                        tx_state_r <= S_STOP;
                    end
                end
                S_STOP: begin
                    if (div_counter_r == 0) begin
                        tx_done_o <= 1'b1;
                        tx_stop_r <= 1'b1;
                        tx_o <= 1'b1;
                        tx_word_count_r <= tx_word_count_r - 1'b1;
                        tx_state_r <= ((STOP-1 - tx_stop_r) == 0) ? S_IDLE : S_STOP;
                    end
                end
                default:
                    tx_state_r <= S_IDLE;
            endcase
        end
    end

endmodule
