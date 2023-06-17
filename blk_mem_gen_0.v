
`timescale 1 ns / 1 ps
module true_dpbram #(
	parameter integer DWIDTH = 16,
	parameter integer AWIDTH = 12,
	parameter integer MEM_SIZE = 32
) (
	clk, 
	addr0, 
	en0, 
	we0, 
	dout0, 
	din0,

	addr1, 
	en1, 
	we1, 
	dout1, 
	din1
);

// parameter DWIDTH = 16;
// parameter AWIDTH = 12;
// parameter MEM_SIZE = 3840;

input clk;

input[AWIDTH-1:0] addr0;
input[AWIDTH-1:0] addr1;
input en0;
input en1;
input we0;
input we1;
output reg[DWIDTH-1:0] dout0;
output reg[DWIDTH-1:0] dout1;
input[DWIDTH-1:0] din0;
input[DWIDTH-1:0] din1;

(* ram_style = "block" *)reg [DWIDTH-1:0] ram [0:MEM_SIZE-1];

always @(posedge clk)  
begin 
    if (en0) begin
        if (we0) 
            ram[addr0] <= din0;
		else
        	dout0 <= ram[addr0];
    end
end

always @(posedge clk)  
begin 
    if (en1) begin
        if (we1) 
            ram[addr1] <= din1;
		else
        	dout1 <= ram[addr1];
    end
end
endmodule
