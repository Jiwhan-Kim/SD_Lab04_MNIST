`timescale 1ns / 1ps

module mac_controller (
    input wire               clk,
    input wire               rstn,
    input wire               en,
    input wire               bias_add,
    input wire               flush,
    input wire               ReLU,

    input wire         [3:0] valid, // whether Input Data is Valid
    input wire        [31:0] input_feature,
    input wire        [31:0] weight,
    input wire        [31:0] bias,

    input wire signed [25:0] result0,
    input wire signed [25:0] result1,
    input wire signed [25:0] result2,
    input wire signed [25:0] result3,

    output reg signed [25:0] out_result,
    output wire       [31:0] out_data,
    output reg               done
);
    wire         [3:0] mac_en;
    wire         [3:0] mac_done;

    wire signed [17:0] mac_result;

    wire signed [15:0] mac_result0;
    wire signed [15:0] mac_result1;
    wire signed [15:0] mac_result2;
    wire signed [15:0] mac_result3;

    assign mac_en[3:0] = en ? valid[3:0] : 4'b0;
    assign mac_result  =   (mac_done[0] ? mac_result0[15:0] : 16'b0)
                         + (mac_done[1] ? mac_result1[15:0] : 16'b0)
                         + (mac_done[2] ? mac_result2[15:0] : 16'b0)
                         + (mac_done[3] ? mac_result3[15:0] : 16'b0);

    mac mac0 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[0]),

        .input_feature (input_feature[7:0]),
        .weight        (weight[7:0]),

        .result        (mac_result0[15:0]),
        .done          (mac_done[0])
    );
    mac mac1 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[1]),

        .input_feature (input_feature[15:8]),
        .weight        (weight[15:8]),

        .result        (mac_result1[15:0]),
        .done          (mac_done[1])
    );
    mac mac2 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[2]),

        .input_feature (input_feature[23:16]),
        .weight        (weight[23:16]),

        .result        (mac_result2[15:0]),
        .done          (mac_done[2])
    );
    mac mac3 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[3]),

        .input_feature (input_feature[31:24]),
        .weight        (weight[31:24]),

        .result        (mac_result3[15:0]),
        .done          (mac_done[3])
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
            out_result <= 26'b0;
            done   <= 1'b0;
        end
        else begin
            if (en) begin
                if (bias_add) begin
                    result_buffer0 <= mac_result0 + (bias0 << 8);
                    result_buffer1 <= mac_result1 + (bias1 << 8);
                    result_buffer2 <= mac_result2 + (bias2 << 8);
                    result_buffer3 <= mac_result3 + (bias3 << 8);

                    out_result <= out_result;
                    done   <= 1'b1;
                end
                else if (mac_done) begin
                    out_result <= out_result + mac_result;
                    done   <= 1'b1;
                end
                else if (flush) begin
                    out_result <= 26'b0;
                    done   <= 1'b1;
                end
                else begin
                    out_result <= out_result;
                    done   <= 1'b0;
                end
            end
        end
    end

    assign out_data[31:24] = ReLU ? (result_buffer0[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer0[24:16] == 9'b0)   ? result_buffer0[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer0[25] == 1'b1) ? (result_buffer0[24:16] == 9'h1ff) ? result_buffer0[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer0[24:16] == 9'b0)   ? result_buffer0[15:8]
                                                                                                     : 8'h7f;
    assign out_data[23:16] = ReLU ? (result_buffer1[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer1[24:16] == 9'b0)   ? result_buffer1[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer1[25] == 1'b1) ? (result_buffer1[24:16] == 9'h1ff) ? result_buffer1[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer1[24:16] == 9'b0)   ? result_buffer1[15:8]
                                                                                                     : 8'h7f;

    assign out_data[15: 8] = ReLU ? (result_buffer2[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer2[24:16] == 9'b0)   ? result_buffer2[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer2[25] == 1'b1) ? (result_buffer2[24:16] == 9'h1ff) ? result_buffer2[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer2[24:16] == 9'b0)   ? result_buffer2[15:8]
                                                                                                     : 8'h7f;

    assign out_data[ 7: 0] = ReLU ? (result_buffer3[25] == 1'b1) ? 8'b0
                                                                 : (result_buffer3[24:16] == 9'b0)   ? result_buffer3[15:8]
                                                                                                     : 8'hff
                                  : (result_buffer3[25] == 1'b1) ? (result_buffer3[24:16] == 9'h1ff) ? result_buffer3[15:8]
                                                                                                     : 8'h80
                                                                 : (result_buffer3[24:16] == 9'b0)   ? result_buffer3[15:8]
                                                                                                     : 8'h7f;
endmodule