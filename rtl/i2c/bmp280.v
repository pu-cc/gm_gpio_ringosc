module bmp280 (
    input         clk,
    input         rstn,
    input         start,
    output reg    data_valid,
    output reg [19:0] temperature,

    // interface to I2C controller
    input              i2c_strobe,
    output reg         i2c_enable,  // one-cycle pulse to start a transaction
    output reg [7:0]   i2c_reg_addr,
    output reg [4:0]   i2c_reg_len,
    input      [7:0]   i2c_reg_rddata,
    output reg [7:0]   i2c_reg_wrdata,
    output reg         i2c_reg_rdwr, // 0 = write, 1 = read
    input              i2c_done
);

    localparam S_INIT            = 0;
    localparam S_IDLE            = 1;

    localparam S_WRITE_TEMP_PTR  = 2;
    localparam S_READ_TEMP       = 4;
    localparam S_READ_TEMP_WAIT  = 5;
    localparam S_DONE            = 10;

    localparam S_WRITE_CALIB_PTR = 11; // 0xA1..0x88
    localparam S_READ_CALIB_WAIT = 12;

    reg [3:0] state = '0;

    // Temporary registers to hold the 3 bytes
    reg [7:0] temp_msb, temp_lsb, temp_xlsb;
    reg [7:0] press_msb, press_lsb, press_xlsb;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
        state          <= S_INIT;
        i2c_enable     <= 1'b0;
        data_valid     <= 1'b0;
        temperature    <= 20'd0;
        temp_msb       <= 8'd0;
        temp_lsb       <= 8'd0;
        temp_xlsb      <= 8'd0;
        i2c_reg_addr   <= 8'h00;
        i2c_reg_rdwr   <= 1'b0;
        i2c_reg_wrdata <= '0;
        i2c_reg_len    <= '0;
        end
        else if (i2c_strobe) begin
            case (state)
                S_INIT: begin
                    data_valid     <= 1'b0;
                    i2c_reg_rdwr   <= 1'b0;
                    i2c_reg_addr   <= 8'hF4; // config ctrl_meas
                    i2c_reg_wrdata <= 8'h23; // osrs_t+osrs_p+mode
                    i2c_enable     <= 1'b1;
                    i2c_reg_len    <= 3;
                    state          <= S_WRITE_TEMP_PTR; //S_WRITE_CALIB_PTR;
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
                        state        <= S_READ_CALIB_WAIT;
                    end
                end

                S_READ_CALIB_WAIT: begin
                    i2c_enable <= 1'b0;
                    if (i2c_done) begin
                        i2c_reg_rdwr <= 1'b1;
                        i2c_enable   <= 1'b1;
                        i2c_reg_len  <= 1+26;
                        state        <= S_READ_TEMP_WAIT;
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
                    if (i2c_done) begin
                        temp_msb <= i2c_reg_rddata;
                        state    <= S_DONE;
                    end
                end

                S_DONE: begin
                    // Wait here until 'start' is deasserted so we don't immediately
                    // begin another transaction.
                    temperature <= 0; //i2c_reg_rddata;
                    //{temp_msb, temp_lsb, temp_xlsb} =
                    data_valid  <= 1'b1;
                    if (!start)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
