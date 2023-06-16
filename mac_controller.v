`timescale 1ns / 1ps

module mac_controller (
    input wire clk,
    input wire rstn
);
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // Reset
        end
        else begin
            // Do
        end
    end
endmodule