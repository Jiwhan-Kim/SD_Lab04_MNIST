`timescale 1ns / 1ps

// Multiplication Unit
module mac (
    input wire               clk,
    input wire               rstn,
    input wire               en,

    input wire         [7:0] input_feature,
    input wire signed  [7:0] weight,

    output reg signed [15:0] result,
    output wire              done
);
    // Control Signal
    wire              en_buffer;

    // Data
    wire        [7:0] input_feature_buffer;
    wire signed [7:0] weight_buffer;

    // Pipeline Stage 0
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // Control Signal
            en_buffer <= 1'b0;

            // Data
            input_feature_buffer <= 8'b0;
            weight_buffer        <= 8'b0;
        end
        else begin
            // Control Signal
            en_buffer                <= en;

            // Data
            if (en) begin
                input_feature_buffer <= input_feature;
                weight_buffer        <= weight;
            end else begin
                input_feature_buffer <= 8'b0;
                weight_buffer        <= 8'b0;
            end
        end
    end

    // Pipeline Stage 1
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // Output Data
            result <= 16'b0;

            // Output Signal
            done   <= 1'b0;
        end
        else begin
            if (en_buffer) begin
                // Output Data
                result <= input_feature_buffer * weight_buffer;

                // Output Signal
                done <= 1'b1;
            end
            else begin
                // Output Data
                result <= 16'b0;

                // Output Signal
                done <= 1'b0;
            end
        end
    end
endmodule