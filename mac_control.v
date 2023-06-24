`timescale 1ns / 1ps

module mac_controller (
    input wire               clk,
    input wire               rstn,
    input wire               en,
    input wire               flush,

    input wire         [3:0] valid, // whether Input Data is Valid
    input wire               last_in,

    input wire        [31:0] input_feature,
    input wire        [31:0] weight,

    output reg signed [25:0] out_result,
    output wire       [31:0] out_data,
    output wire              last_out, // for Control Signals
    output reg               done // for Data Access
);
    wire         [3:0] mac_en;
    assign mac_en[3:0] = en ? valid[3:0] : 4'b0;

    wire         [3:0] mac_last_out;
    assign last_out = (mac_last_out != 4'b0) ? 1'b1 : 1'b0;
    wire         [3:0] mac_done;

    wire signed [15:0] mac_result0;
    wire signed [15:0] mac_result1;
    wire signed [15:0] mac_result2;
    wire signed [15:0] mac_result3;

    wire signed [16:0] mac_result_01;
    wire signed [16:0] mac_result_23;
    
    wire signed [17:0] mac_result;
    assign mac_result_01 = mac_result0 + mac_result1;
    assign mac_result_23 = mac_result2 + mac_result3;
    assign mac_result    = mac_result_01 + mac_result_23;

    mac mac0 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[0]),

        .last_in       (last_in),
        .input_feature (input_feature[7:0]),
        .weight        (weight[7:0]),

        .result        (mac_result0[15:0]),
        .last_out      (mac_last_out[0]),
        .done          (mac_done[0])
    );
    mac mac1 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[1]),

        .last_in       (last_in),
        .input_feature (input_feature[15:8]),
        .weight        (weight[15:8]),

        .result        (mac_result1[15:0]),
        .last_out      (mac_last_out[1]),
        .done          (mac_done[1])
    );
    mac mac2 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[2]),

        .last_in       (last_in),
        .input_feature (input_feature[23:16]),
        .weight        (weight[23:16]),

        .result        (mac_result2[15:0]),
        .last_out      (mac_last_out[2]),
        .done          (mac_done[2])
    );
    mac mac3 (
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en[3]),

        .last_in       (last_in),
        .input_feature (input_feature[31:24]),
        .weight        (weight[31:24]),

        .result        (mac_result3[15:0]),
        .last_out      (mac_last_out[3]),
        .done          (mac_done[3])
    );

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            out_result <= 26'b0;
            done   <= 1'b0;
        end
        else begin
            if (en) begin
                if (mac_done) begin
                    out_result <= out_result + mac_result;
                    done       <= (mac_last_out != 4'b0) ? 1'b1 : 1'b0;
                end
                else if (flush) begin
                    out_result  <= mac_result;
                    done        <= 1'b0;
                end
                else begin
                    out_result <= out_result;
                    done        <= 1'b0;
                end
            end
        end
    end


endmodule