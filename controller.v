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
        STATE_IDLE              =  'd0,
        STATE_OUT_RECEIVE       = 1'd1,
        STATE_INPUT_SET         = 1'd1,
        
        STATE_WEIGHT_SET        = 3'd1,

        STATE_BIAS_SET          = 3'd2;

    // Global Data
    reg  [63:0] input_feature;
    reg  [63:0] input_feature_buffer;
    reg  [63:0] bias_vector;
    reg  [63:0] weight;
    
    // BRAM 0 FSM
    // BRAM 0 State
    reg         bram_state0a;
    reg         bram_state0b;

    // BRAM 0 Datas
    reg   [8:0] bram_addr0a; // write
    reg  [31:0] bram_din0a;
    
    reg   [8:0] bram_addr0b; // read
    wire [31:0] bram_dout0b;
    
    // BRAM 0 Control Signals
    reg         bram_en0a;
    reg         bram_we0a;

    reg         bram_en0b;

    // BRAM 0 FSM Control Signals
    reg   [1:0] bram_latency0a;
    reg   [7:0] bram_counter0a;
    reg         bram_write_done0a;

    reg   [1:0] bram_latency0b;
    reg   [7:0] bram_counter0b;
    reg         bram_write_done0b;

    blk_mem_gen_0 ( // Simple Dual Port BRAM
        // Port a for Write Data
        .clka     (clk),
        .ena      (bram_en0a),
        .wea      (bram_we0a),
        .addra    (bram_addr0a),
        .dina     (bram_din0a),
        
        // Port b for Read Data
        .clkb     (clk),
        .enb      (bram_en0b),
        .addrb    (bram_addr0b),
        .doutb    (bram_dout0b)
    );

    // BRAM 0 Port a FSM: Write Data
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // BRAM 0 Port a State
            bram_state0a        <= STATE_IDLE;

            // BRAM 0 Port a Datas
            bram_addr0a         <= 9'h1ff; // NULL Address
            bram_din0a          <= 32'b0;
            
            // BRAM 0 Port a Control Signals
            bram_en0a           <= 1'b0;
            bram_we0a           <= 1'b0;

            // BRAM 0 Port a Control Signals
            bram_latency0a      <= 2'b0;
            bram_counter0a      <= 8'b0;
            bram_write_done0a   <= 1'b0;
        end
        else begin
            case (bram_state0a)
                STATE_IDLE: begin
                    // BRAM 0 Port a State
                    if (r_valid) bram_state0a <= STATE_OUT_RECEIVE;
                    else bram_state0a <= STATE_IDLE;

                    // BRAM 0 Port a Datas
                    bram_addr0a         <= 9'h1ff; // NULL Address
                    bram_din0a          <= 32'b0;
                    
                    // BRAM 0 Port a Control Signals
                    bram_en0a           <= 1'b0;
                    bram_we0a           <= 1'b0;

                    // BRAM 0 Port a FSM Control Signals
                    bram_latency0a      <= 2'b0;
                    bram_counter0a      <= 8'b0;
                    bram_write_done0a   <= 1'b0;
                end
                STATE_OUT_RECEIVE: begin

                end
            endcase
        end
    end

    // BRAM 0 Port b FSM: Read Data
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // BRAM 0 Port b State
            bram_state0b        <= STATE_IDLE;

            // BRAM 0 Port b Datas
            bram_addr0b         <= 9'h1ff; // NULL Address
            
            // BRAM 0 Port b Control Signals
            bram_en0b           <= 1'b0;

            // BRAM 0 Port b Control Signals
            bram_latency0b      <= 2'b0;
            bram_counter0b      <= 8'b0;
            bram_write_done0b   <= 1'b0;
        end
        else begin
            case (bram_state0b)
                STATE_IDLE: begin
                    // BRAM 0 Port b State
                    if (r_valid) bram_state0b <= STATE_INPUT_SET;
                    else bram_state0b <= STATE_IDLE;

                    // BRAM 0 Port b Datas
                    bram_addr0b         <= 9'h1ff; // NULL Address
                    bram_din0b          <= 32'b0;
                    
                    // BRAM 0 Port b Control Signals
                    bram_en0b           <= 1'b0;

                    // BRAM 0 Port b FSM Control Signals
                    bram_latency0b      <= 2'b0;
                    bram_counter0b      <= 8'b0;
                    bram_write_done0b   <= 1'b0;
                end
                STATE_INPUT_SET: begin
                end
            endcase
        end
    end

    // BRAM 1 FSM
    // BRAM 1 State
    reg  [2:0]  bram_state1;

    // BRAM 1 Datas
    reg  [15:0] bram_addr1;
    reg  [31:0] bram_din1;
    wire [31:0] bram_dout1;
    
    // BRAM 1 Control Signals
    reg         bram_en1;
    reg         bram_we1;

    // BRAM 1 FSM Control Signals
    reg  [1:0]  bram_latency1;
    reg  [7:0]  bram_counter1;
    reg         bram_write_done1;

    blk_mem_gen_1 ( // Single Port BRAM
        clka      (clk),
        ena       (bram_en1),
        wea       (bram_we1),
        addra     (bram_addr1),
        dina      (bram_din1),
        douta     (bram_dout1)
    );
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // BRAM 1 State
            bram_state1         <= STATE_IDLE;

            // BRAM 1 Datas
            bram_addr1          <= 16'hffff; // NULL Address
            
            // BRAM 1 Control Signals
            bram_en1            <= 1'b0;
            bram_we1            <= 1'b0;

            // BRAM 1 FSM Control Signals
            bram_latency1       <= 2'b0;
            bram_counter1       <= 8'b0;
            bram_write_done1    <= 1'b0;
        end
        else begin
            case (bram_state1)
                STATE_IDLE: begin
                    bram_state1         <= STATE_IDLE;
                end
            endcase
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