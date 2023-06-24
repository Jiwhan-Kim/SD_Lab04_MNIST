`timescale 1ns / 1ps

module bias_add(
    input wire clk,
    input wire rstn,

    input wire en,
    input wire add,
    input wire ReLU,

    input wire [31:0] bias,

    input wire signed [25:0] result0,
    input wire signed [25:0] result1,
    input wire signed [25:0] result2,
    input wire signed [25:0] result3,

    output wire [31:0] out_data
);

    wire signed  [7:0] bias0;
    wire signed  [7:0] bias1;
    wire signed  [7:0] bias2;
    wire signed  [7:0] bias3;

    assign bias0 = bias[31:24];
    assign bias1 = bias[23:16];
    assign bias2 = bias[15:8];
    assign bias3 = bias[7:0];
    
    reg  signed [25:0] result_buffer0;
    reg  signed [25:0] result_buffer1;
    reg  signed [25:0] result_buffer2;
    reg  signed [25:0] result_buffer3;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            result_buffer0 <= 26'b0;
            result_buffer1 <= 26'b0;
            result_buffer2 <= 26'b0;
            result_buffer3 <= 26'b0;
        end
        else begin
            if (en && add) begin
                result_buffer0 <= result0 + (bias0 << 8);
                result_buffer1 <= result1 + (bias1 << 8);
                result_buffer2 <= result2 + (bias2 << 8);
                result_buffer3 <= result3 + (bias3 << 8);
            end
            else if (en) begin
                result_buffer0 <= result_buffer0;
                result_buffer1 <= result_buffer1;
                result_buffer2 <= result_buffer2;
                result_buffer3 <= result_buffer3;
            end
            else begin
                result_buffer0 <= 26'b0;
                result_buffer1 <= 26'b0;
                result_buffer2 <= 26'b0;
                result_buffer3 <= 26'b0;
            end
        end
    end

    assign out_data[31:24] = ReLU ? (result_buffer0[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer0[24:16] == 9'b0)   ? result_buffer0[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer0[25] == 1'b1) ? (result_buffer0[24:15] == 10'h2ff) ? result_buffer0[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer0[24:15] == 10'b0)   ? result_buffer0[15:8]
                                                                                                     : 8'h7f;
    assign out_data[23:16] = ReLU ? (result_buffer1[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer1[24:16] == 9'b0)   ? result_buffer1[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer1[25] == 1'b1) ? (result_buffer1[24:15] == 10'h2ff) ? result_buffer1[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer1[24:15] == 9'b0)   ? result_buffer1[15:8]
                                                                                                     : 8'h7f;

    assign out_data[15: 8] = ReLU ? (result_buffer2[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer2[24:16] == 9'b0)   ? result_buffer2[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer2[25] == 1'b1) ? (result_buffer2[24:15] == 10'h2ff) ? result_buffer2[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer2[24:15] == 9'b0)   ? result_buffer2[15:8]
                                                                                                     : 8'h7f;

    assign out_data[ 7: 0] = ReLU ? (result_buffer3[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer3[24:16] == 9'b0)   ? result_buffer3[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer3[25] == 1'b1) ? (result_buffer3[24:15] == 10'h2ff) ? result_buffer3[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer3[24:15] == 9'b0)   ? result_buffer3[15:8]
                                                                                                     : 8'h7f;
endmodule