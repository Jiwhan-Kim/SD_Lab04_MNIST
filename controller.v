`timescale 1ns / 1ps

module student_fc_controller(
    input wire  clk,
    input wire  rstn,
    input wire  r_valid,
    
    output wire out_data,
    output wire t_valid
);
    localparam
        // Global Constants
        BYTE_SIZE               = 32'h8,

        MEM_LATENCY             = 2'h2,
        LAYER_SIZE              = 2'h3,
        MEM0_SIZE               = 9'd271,
        MEM1_SIZE               = 16'd59628,
        MEM0_AWIDTH             = 9,
        MEM1_AWDITH             = 16,

        X_SIZE_0                = 16'd784,
        W_SIZE_0                = 16'd300 * 16'd784,
        B_SIZE_0                = 16'd300,

        X_SIZE_1                = 16'd300,
        W_SIZE_1                = 16'd10 * 16'd300,
        B_SIZE_1                = 16'd10,

        INPUT0_START_ADDRESS    = 9'h0,
        INPUT1_START_ADDRESS    = 9'hc4, // 9'd196

        WEIGHT0_START_ADDRESS   = 16'h0,
        BIAS0_START_ADDRESS     = 16'he5b0, // 16'd58800 = (16'd784 * 16'd300) >> 2
        WEIGHT1_START_ADDRESS   = 16'he5fb, // 16'd58875 = (16'd784 * 16'd300 + 16'd300) >> 2
        BIAS1_START_ADDRESS     = 16'he8e9, // 16'd59625 = (16'd300 * 16'd784 + 16'd300 + 16'd10 * 16'd300) >> 2

        // BRAM States
        STATE_IDLE              = 3'd0,
        STATE_INPUT_SET         = 3'd1,
        STATE_WEIGHT_SET        = 3'd1,
        STATE_OUT_RECEIVE       = 3'd2,
        STATE_BIAS_SET          = 3'd2;

    // Global Data
    reg  [63:0] input_feature;
    reg  [63:0] input_feature_buffer;
    reg  [63:0] bias_vector;
    reg  [63:0] weight;
    true_dpbram #(.DWIDTH()) bram0 (

    );

    true_dpbram #(.DWIDTH()) bram1 (

    );

    // BRAM Port 0 FSM
    // BRAM Port 0 State
    reg   [2:0] bram_state0;

    // BRAM Port 0 Datas
    reg   [8:0] bram_addr0;
    reg  [31:0] bram_din0;
    wire [31:0] bram_dout0;
    
    // BRAM Port 0 Control Signals
    reg         bram_en0;
    reg         bram_we0;
    reg   [1:0] bram_latency0;
    reg   [7:0] bram_counter0;
    reg         bram_write_done0;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // BRAM Port 0 State
            bram_state0         <= STATE_IDLE;

            // BRAM Port 0 Datas
            bram_addr0          <= 9'h1ff; // NULL Address
            bram_din0           <= 32'b0;
            
            // BRAM Port 0 Control Signals
            bram_en0            <= 1'b0;
            bram_we0            <= 1'b0;
            bram_latency0       <= 2'b0;
            bram_counter0       <= 8'b0;
            bram_write_done0    <= 1'b0;
        end
        else begin
            case (state)
                STATE_IDLE: begin
                    // BRAM Port 0 State
                    if (r_valid) bram_state0 <= STATE_INPUT_SET;
                    else bram_state0 <= STATE_IDLE;

                    // BRAM Port 0 Datas
                    bram_addr0          <= 9'h1ff; // NULL Address
                    bram_din0           <= 32'b0;
                    
                    // BRAM Port 0 Control Signals
                    bram_en0            <= 1'b0;
                    bram_we0            <= 1'b0;
                    bram_latency0       <= 2'b0;
                    bram_counter0       <= 8'b0;
                    bram_write_done0    <= 1'b0;
                end
                STATE_INPUT_SET: begin

                end
                STATE_OUT_RECEIVE: begin
                end
            endcase
        end
    end

    // BRAM Port 1 FSM
    // BRAM Port 1 State
    reg  [2:0]  bram_state1;

    // BRAM Port 1 Datas
    reg  [15:0]  bram_addr1;
    wire [31:0] bram_dout1;
    
    // BRAM Port 1 Control Signals
    reg         bram_en1;
    reg         bram_we1;
    reg  [1:0]  bram_latency1;
    reg  [7:0]  bram_counter1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // BRAM Port 1 State
            bram_state1         <= STATE_IDLE;

            // BRAM Port 1 Datas
            bram_addr1          <= 16'hffff; // NULL Address
            
            // BRAM Port 1 Control Signals
            bram_en1            <= 1'b0;
            bram_we1            <= 1'b0;
            bram_latency1       <= 2'b0;
            bram_counter1       <= 8'b0;
        end
        else begin
            bram_state1         <= STATE_IDLE;
        end
    end

    // MAC Control FSM
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
        end
        else begin
        end
    end
endmodule