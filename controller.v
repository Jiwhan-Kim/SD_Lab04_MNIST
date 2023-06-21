`timescale 1ns / 1ps

module student_fc_controller(
    input wire  clk,
    input wire  rstn,
    input wire  r_valid,
    
    output reg [3:0] out_data,
    output reg t_valid
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

        STAGE                   = 2,        // Two Stage with one Hidden Layer
        X_SIZE_0                = 16'd784,
        W_SIZE_0                = 32'd300 * 32'd784,
        B_SIZE_0                = 16'd300,

        X_SIZE_1                = 16'd300,
        W_SIZE_1                = 32'd10 * 32'd300,
        B_SIZE_1                = 16'd10,

        INPUT0_START_ADDRESS    = 9'h0,
        INPUT1_START_ADDRESS    = 9'hc4,    // 9'd196

        WEIGHT0_START_ADDRESS   = 16'h0,
        BIAS0_START_ADDRESS     = 16'he5b0, // 16'd58800 = (16'd784 * 16'd300) >> 2
        WEIGHT1_START_ADDRESS   = 16'he5fb, // 16'd58875 = (16'd784 * 16'd300 + 16'd300) >> 2
        BIAS1_START_ADDRESS     = 16'he8e9, // 16'd59625 = (16'd300 * 16'd784 + 16'd300 + 16'd10 * 16'd300) >> 2

        // BRAM States
        STATE_IDLE              =  'd0,
        STATE_OUT_RECEIVE       = 1'd1,
        STATE_INPUT_SET         = 2'd1,
        STATE_WEIGHT_SET        = 2'd1,
        STATE_BIAS_SET          = 2'd2,
        STATE_BRAM_CHECK        = 2'd3,

        STATE_ACCM              = 3'd1,
        STATE_BUFFER            = 3'd2,
        STATE_BIAS_ADD          = 3'd3,
        STATE_WAIT              = 3'd4,
        STATE_DATA_SEND         = 3'd5;

    // Global Data
    reg   [1:0] layer;
    reg  [31:0] input_feature;
    reg  [31:0] bias;
    reg  [31:0] weight;

    reg [25:0] output_result0;
    reg [25:0] output_result1;
    reg [25:0] output_result2;
    reg [25:0] output_result3;

    wire [31:0] quad_result;
    
    reg signed [7:0] max_value;

    reg   [8:0] INPUT_START_ADDRESS;
    reg  [15:0] WEIGHT_START_ADDRESS;
    reg  [15:0] BIAS_START_ADDRESS;
    reg   [8:0] OUTPUT_START_ADDRESS;

    reg  [15:0] X_SIZE;
    reg  [31:0] W_SIZE;
    reg  [15:0] B_SIZE;

    reg  [15:0] input_cnt;
    reg  [15:0] output_cnt;

    reg   [3:0] data_valid;

    always @(*) begin
        case (layer)
            2'b00: begin
                INPUT_START_ADDRESS  <= INPUT0_START_ADDRESS;
                WEIGHT_START_ADDRESS <= WEIGHT0_START_ADDRESS;
                BIAS_START_ADDRESS   <= BIAS0_START_ADDRESS;
                OUTPUT_START_ADDRESS <= INPUT1_START_ADDRESS;

                X_SIZE               <= X_SIZE_0;
                W_SIZE               <= W_SIZE_0;
                B_SIZE               <= B_SIZE_0;
            end
            2'b01: begin
                INPUT_START_ADDRESS  <= INPUT1_START_ADDRESS;
                WEIGHT_START_ADDRESS <= WEIGHT1_START_ADDRESS;
                BIAS_START_ADDRESS   <= BIAS1_START_ADDRESS;
                OUTPUT_START_ADDRESS <= INPUT1_START_ADDRESS;

                X_SIZE               <= X_SIZE_1;
                W_SIZE               <= W_SIZE_1;
                B_SIZE               <= B_SIZE_1;
            end
            default: begin
                X_SIZE <= 16'b0;
                W_SIZE <= 32'b0;
                B_SIZE <= 16'b0;
            end
        endcase
    end

    // BRAM 0 FSM
    // BRAM 0 State
    reg         bram_state0a;
    reg   [1:0] bram_state0b;

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
    reg  [15:0] bram_counter0a;
    reg         bram_write_done0a;

    reg   [1:0] bram_latency0b;
    reg  [15:0] bram_counter0b;
    reg         input_set_done;

    blk_mem_gen_0 bram0 ( // Simple Dual Port BRAM
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
                    if (r_valid && ((layer + 1'b1) < STAGE) && (output_cnt < B_SIZE)) begin
                        bram_state0a <= STATE_OUT_RECEIVE;
                    end 
                    else begin
                        bram_state0a <= STATE_IDLE;
                    end

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
                    if (bram_write_done0a) begin
                        // BRAM 0 Port a State
                        bram_state0a        <= STATE_IDLE;

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
                    else begin
                        if (mac_state == STATE_DATA_SEND) begin
                            // BRAM 0 Port a State
                            bram_state0a    <= STATE_OUT_RECEIVE;
                            
                            // BRAM 0 Port a Datas
                            bram_addr0a <= OUTPUT_START_ADDRESS + (output_cnt >> 2) - 9'b1;
                            bram_din0a[31:0] <= quad_result[31:0];

                            // BRAM 0 Port a Control Signals
                            bram_en0a <= 1'b1;
                            bram_we0a <= 1'b1;

                            // BRAM 0 Port a FSM Control Signals
                            bram_latency0a <= 2'b0;
                            bram_counter0a <= 8'b0;
                            bram_write_done0a <= 1'b1;
                        end
                        else begin
                            // BRAM 0 Port a State
                            bram_state0a        <= STATE_OUT_RECEIVE;

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
                    end
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
            bram_counter0b      <= 16'b0;
            input_set_done      <= 1'b0;

            // Global Data
            input_feature       <= 32'b0;
        end
        else begin
            case (bram_state0b)
                STATE_IDLE: begin
                    // BRAM 0 Port b State
                    if (r_valid && (layer < STAGE)) begin
                        bram_state0b <= STATE_BRAM_CHECK;
                    end 
                    else begin
                        bram_state0b <= STATE_IDLE;
                    end

                    // BRAM 0 Port b Datas
                    bram_addr0b         <= 9'h1ff; // NULL Address
                    
                    // BRAM 0 Port b Control Signals
                    bram_en0b           <= 1'b0;

                    // BRAM 0 Port b FSM Control Signals
                    bram_latency0b      <= 2'b0;
                    bram_counter0b      <= 16'b0;
                    input_set_done      <= 1'b0;

                    // Global Data
                    input_feature       <= 32'b0;
                end
                STATE_INPUT_SET: begin
                    if ((input_cnt << 2) >= X_SIZE) begin
                        // BRAM 0 Port b State
                        if ((output_cnt + 1) < B_SIZE) begin
                            bram_state0b <= STATE_BRAM_CHECK;
                        end
                        else begin
                            bram_state0b <= STATE_IDLE;
                        end

                        // BRAM 0 Port b Datas
                        bram_addr0b      <= 9'h1ff;

                        // BRAM 0 Port b Control Signals
                        bram_en0b        <= 1'b0;

                        // BRAM 0 Port b FSM Control Signals
                        bram_latency0b   <= 2'b0;
                        bram_counter0b   <= 16'b0;
                        input_set_done   <= 1'b0;

                        // Global Data
                        input_feature    <= 32'b0;
                    end
                    else begin
                        // BRAM 0 Port b State
                        bram_state0b    <= STATE_INPUT_SET;
                        
                        // BRAM 0 Port b Datas
                        if ((bram_counter0b << 2) < X_SIZE) begin
                            bram_addr0b <= INPUT_START_ADDRESS + bram_counter0b;
                        end 
                        // input_feature

                        // BRAM 0 Port b Control Signals
                        bram_en0b       <= 1'b1;

                        // BRAM 0 Port b FSM Control Signals
                        if (bram_latency0b < MEM_LATENCY + 1) begin
                            bram_latency0b <= bram_latency0b + 1'b1;
                            input_set_done <= 1'b0;
                        end else begin
                            $display("%d %d %h %h", output_cnt, input_cnt, bram_addr0b, bram_dout0b);
                            input_feature <= bram_dout0b;
                            input_set_done <= 1'b1;
                        end

                        bram_counter0b <= bram_counter0b + 1'b1;
                    end
                end

                STATE_BRAM_CHECK: begin
                    // BRAM 0 Port b State
                    if (mac_state == STATE_IDLE && bram_state1 == STATE_BRAM_CHECK) begin
                        bram_state0b    <= STATE_INPUT_SET;
                    end 
                    else begin
                        bram_state0b    <= STATE_BRAM_CHECK;
                    end

                    // BRAM 0 Port b Datas
                    bram_addr0b         <= 9'h1ff; // NULL Address
                    
                    // BRAM 0 Port b Control Signals
                    bram_en0b           <= 1'b0;

                    // BRAM 0 Port b FSM Control Signals
                    bram_latency0b      <= 2'b0;
                    bram_counter0b      <= 16'b0;
                    input_set_done      <= 1'b0;

                    // Global Data
                    input_feature       <= 32'b0;
                end
            endcase
        end
    end

    // BRAM 1 FSM
    // BRAM 1 State
    reg   [1:0] bram_state1;

    // BRAM 1 Datas
    reg  [15:0] bram_addr1;
    reg  [31:0] bram_din1;
    wire [31:0] bram_dout1;
    
    // BRAM 1 Control Signals
    reg         bram_en1;
    reg         bram_we1;

    // BRAM 1 FSM Control Signals
    reg  [1:0]  bram_latency1;
    reg [15:0]  bram_counter1;
  //reg         bram_write_done1;
    reg         weight_set_done;
    reg         bias_set_done;

    blk_mem_gen_1 bram1 ( // Single Port BRAM
        .clka      (clk),
        .ena       (bram_en1),
        .wea       (bram_we1),
        .addra     (bram_addr1),
        .dina      (bram_din1),
        .douta     (bram_dout1)
    );

    // BRAM 1 FSM: Mainly Read Data
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
            weight_set_done     <= 1'b0;
            bias_set_done       <= 1'b0;

            // Global Data
            weight              <= 32'b0;
            bias                <= 32'b0;
            input_cnt           <= 16'b0;
            output_cnt          <= 16'b0;
            data_valid          <= 4'b0;
            layer               <= 2'b0;
        end
        else begin
            case (bram_state1)
                STATE_IDLE: begin
                    // BRAM 1 State
                    if (r_valid && mac_state == STATE_IDLE && (layer < STAGE)) begin
                        t_valid <= 1'b0;
                        bram_state1     <= STATE_BRAM_CHECK;
                        
                        input_cnt           <= 16'b0;
                        output_cnt          <= 16'b0;
                    end 
                    else if (layer >= STAGE) begin
                        t_valid <= 1'b1;
                        bram_state1     <= STATE_IDLE;
                        
                        input_cnt           <= input_cnt;
                        output_cnt          <= output_cnt;
                    end
                    else begin
                        t_valid <= 1'b0;
                        bram_state1     <= STATE_IDLE;
                        
                                    
                        input_cnt           <= input_cnt;
                        output_cnt          <= output_cnt;
                    end

                    // BRAM 1 Datas
                    bram_addr1          <= 16'hffff; // NULL Address
                    
                    // BRAM 1 Control Signals
                    bram_en1            <= 1'b0;
                    bram_we1            <= 1'b0;

                    // BRAM 1 FSM Control Signals
                    bram_latency1       <= 2'b0;
                    bram_counter1       <= 8'b0;
                    weight_set_done     <= 1'b0;
                    bias_set_done       <= 1'b0;

                    // Global Data
                    weight              <= 32'b0;
                    bias                <= 32'b0;
                    data_valid          <= 4'b0;
                    layer               <= layer;
                end

                STATE_BRAM_CHECK: begin
                    // BRAM 1 State
                    if (mac_state == STATE_IDLE && bram_state0b == STATE_BRAM_CHECK) begin
                        bram_state1     <= STATE_WEIGHT_SET;
                    end
                    else begin
                        bram_state1     <= STATE_BRAM_CHECK;
                    end

                    // BRAM 1 Datas
                    bram_addr1          <= 16'hffff;

                    // BRAM 1 Control Signals
                    bram_en1            <= 1'b0;
                    bram_we1            <= 1'b0;

                    // BRAM 1 FSM Control Signals
                    bram_latency1       <= 2'b0;
                    bram_counter1       <= 16'b0;
                    bias_set_done       <= bias_set_done;
                    weight_set_done     <= 1'b0;

                    // Global Data
                    input_cnt           <= input_cnt;
                    output_cnt          <= output_cnt;
                    data_valid          <= 4'b0000;
                    layer               <= layer;
                end

                STATE_WEIGHT_SET: begin
                    if ((input_cnt << 2) >= X_SIZE) begin
                        // BRAM 1 State
                        if (output_cnt[1:0] == 2'b11 || (output_cnt + 1'b1 >= B_SIZE)) begin
                            bram_state1 <= STATE_BIAS_SET;
                        end
                        else begin
                            bram_state1 <= STATE_BRAM_CHECK;
                        end
                        
                        // BRAM 1 Datas
                        bram_addr1      <= 16'hffff;

                        // BRAM 1 Control Signals
                        bram_en1        <= 1'b0;
                        bram_we1        <= 1'b0;

                        // BRAM 1 FSM Control Signals
                        bram_latency1   <= 2'b0;
                        bram_counter1   <= 16'b0;
                        weight_set_done <= 1'b0;
                        bias_set_done   <= bias_set_done;

                        // Global Data
                        input_cnt       <= 16'b0;
                        output_cnt      <= output_cnt + 1'b1;
                        data_valid      <= 4'b0000;
                        layer           <= layer;
                    end
                    else begin
                        // BRAM 1 State
                        bram_state1     <= STATE_WEIGHT_SET;
                        
                        // BRAM 1 Datas
                        if ((bram_counter1 << 2) < X_SIZE) begin
                            bram_addr1 <= WEIGHT_START_ADDRESS + output_cnt * (X_SIZE >> 2) + bram_counter1;
                        end 
                        // weight

                        // BRAM 1 Control Signals
                        bram_en1       <= 1'b1;
                        bram_we1       <= 1'b0;

                        // BRAM 1 FSM Control Signals
                        if (bram_latency1 < MEM_LATENCY + 1) begin
                            bram_latency1   <= bram_latency1 + 1'b1;
                            weight_set_done <= 1'b0;

                            // Global Data
                            input_cnt       <= input_cnt;
                            data_valid      <= 4'b0;
                        end else begin
                            weight <= bram_dout1;
                            weight_set_done <= 1'b1;
                            
                            // Global Data
                            input_cnt       <= input_cnt + 1'b1;
                            data_valid      <= 4'b1111 << ((X_SIZE - (input_cnt << 2)) >= 16'h4 ? 2'h0 : (3'h4 - (X_SIZE - (input_cnt << 2))));
                        end
                        bram_counter1 <= bram_counter1 + 1'b1;

                        // Global Data
                        output_cnt <= output_cnt;
                        layer      <= layer;
                    end
                end

                STATE_BIAS_SET: begin
                    if (bias_set_done) begin
                        if (mac_state == STATE_BIAS_ADD) begin
                            // BRAM 1 State
                            if (output_cnt >= B_SIZE) begin
                                bram_state1      <= STATE_IDLE;
                                layer            <= layer + 1'b1;
                            end
                            else begin
                                bram_state1      <= STATE_BRAM_CHECK;
                                layer            <= layer;
                            end
                            // Global Data
                            bias_set_done   <= 1'b0;
                        end
                        else begin
                            // BRAM 1 State
                            bram_state1     <= STATE_BIAS_SET;

                            // Global Data
                            bias_set_done   <= 1'b1;
                        end

                        // BRAM 1 Datas
                        bram_addr1      <= 16'hffff;

                        // BRAM 1 Control Signals
                        bram_en1        <= 1'b0;
                        bram_we1        <= 1'b0;

                        // BRAM 1 FSM Control Signals
                        bram_latency1   <= 2'b0;
                        bram_counter1   <= 16'b0;
                        weight_set_done <= 1'b0;

                        // Global Data
                        input_cnt           <= input_cnt;
                        output_cnt          <= output_cnt;
                        data_valid          <= 4'b1111;
                    end
                    else begin
                        // BRAM 1 State
                        bram_state1     <= STATE_BIAS_SET;
                        
                        // BRAM 1 Datas
                        bram_addr1      <= BIAS_START_ADDRESS + (output_cnt >> 2);
                        // bias

                        // BRAM 1 Control Signals
                        bram_en1       <= 1'b1;
                        bram_we1       <= 1'b0;

                        // BRAM 1 FSM Control Signals
                        if (bram_latency1 < MEM_LATENCY + 1) begin
                            bram_latency1 <= bram_latency1 + 1'b1;
                            bias_set_done <= 1'b0;
                        end else begin
                            bias <= bram_dout1;
                            bias_set_done <= 1'b1;
                        end
                        weight_set_done <= 1'b0;
                        
                        // Global Data
                        input_cnt  <= input_cnt;
                        output_cnt <= output_cnt;
                        data_valid <= data_valid;
                        layer      <= layer;
                    end
                end
            endcase
        end
    end

    // MAC Controller FSM
    // MAC Controller State
    reg          [2:0] mac_state;

    // MAC Datas
    wire signed [25:0] mac_result;

    // MAC Control Signal
    reg                mac_en;
    reg                mac_add;
    reg                mac_flush;

    wire         [3:0] mac_valid;

    reg                ReLU;

    assign mac_valid = data_valid;

    mac_controller controller(
        .clk           (clk),
        .rstn          (rstn),
        .en            (mac_en),
        .bias_add      (mac_add),
        .flush         (mac_flush),
        .ReLU          (ReLU),

        .valid         (mac_valid[3:0]),
        .input_feature (input_feature[31:0]),
        .weight        (weight[31:0]),
        .bias          (bias[31:0]),

        .result0       (output_result0[25:0]),
        .result1       (output_result1[25:0]),
        .result2       (output_result2[25:0]),
        .result3       (output_result3[25:0]),

        .out_result    (mac_result[25:0]),
        .out_data      (quad_result[31:0]),
        .done          (done)
    );

    // MAC Control FSM
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // MAC Controller State
            mac_state   <= STATE_IDLE;

            // MAC Control Signal
            mac_en      <= 1'b0;
            mac_add     <= 1'b0;
            mac_flush   <= 1'b0;

            ReLU        <= 1'b0;

            // Global Data
            out_data    <= 4'b0;
            max_value   <= 8'h80;
        end
        else begin
            case (mac_state)
                STATE_IDLE: begin
                    // MAC Controller State
                    if (bram_state1 == STATE_BRAM_CHECK) begin
                        mac_state   <= STATE_ACCM;
                    end
                    else begin
                        mac_state   <= STATE_IDLE;
                    end
                    
                    // MAC Control Signal
                    mac_en      <= 1'b0;
                    mac_add     <= 1'b0;
                    mac_flush   <= 1'b0;

                    ReLU        <= 1'b0;
                end

                STATE_ACCM: begin
                    // MAC Controller State
                    if ((input_cnt << 2) >= X_SIZE) begin
                        mac_state <= STATE_BUFFER;
                    end
                    else begin
                        mac_state <= STATE_ACCM;
                    end

                    // MAC Control Signal
                    mac_en      <= 1'b1;
                    mac_add     <= 1'b0;
                    mac_flush   <= 1'b0;

                    ReLU        <= 1'bx;
                end

                STATE_BUFFER: begin
                    if (done) begin
                        // MAC Controller State
                        mac_state <= STATE_BUFFER;

                        // MAC Control Signal
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b0;
                        mac_flush   <= 1'b0;

                        ReLU        <= 1'bx;
                    end
                    else begin
                        case (output_cnt[1:0])
                            2'b01: output_result0 <= mac_result;
                            2'b10: output_result1 <= mac_result;
                            2'b11: output_result2 <= mac_result;
                            2'b00: output_result3 <= mac_result;
                        endcase

                        if (output_cnt[1:0] == 2'b00 || (output_cnt >= B_SIZE)) begin
                            // MAC Controller State
                            mac_state <= STATE_BIAS_ADD;

                            // MAC Control Signal
                            mac_en      <= 1'b1;
                            mac_add     <= 1'b0;
                            mac_flush   <= 1'b1;

                            ReLU        <= 1'bx;
                        end
                        else begin
                            // MAC Controller State
                            mac_state <= STATE_IDLE;

                            mac_en      <= 1'b1;
                            mac_add     <= 1'b0;
                            mac_flush   <= 1'b1;

                            ReLU        <= 1'bx;
                        end
                    end
                end

                STATE_BIAS_ADD: begin
                    if (bias_set_done) begin
                        // MAC Controller State
                        mac_state <= STATE_WAIT;

                        // MAC Control Signal
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b1;
                        mac_flush   <= 1'b0;

                        ReLU        <= (layer + 1'b1 < STAGE);
                    end
                    else begin
                        // MAC Controller State
                        mac_state   <= STATE_BIAS_ADD;

                        // MAC Control Signals
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b0;
                        mac_flush   <= 1'b0;
                        
                        ReLU        <= (layer + 1'b1 < STAGE);
                    end
                end

                STATE_WAIT: begin
                    if (!done) begin
                        // MAC Controller State
                        mac_state <= STATE_WAIT;

                        // MAC Control Signal
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b0;
                        mac_flush   <= 1'b0;

                        ReLU        <= (layer + 1'b1 < STAGE);
                    end
                    else begin
                        // MAC Controller State
                        mac_state <= STATE_DATA_SEND;
                        
                        // MAC Control Signal
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b0;
                        mac_flush   <= 1'b0;

                        ReLU        <= (layer + 1'b1 < STAGE);
                    end
                end
                
                STATE_DATA_SEND: begin
                    // MAC Controller State
                    mac_state <= STATE_IDLE;
                    
                    if (layer + 1'b1 < STAGE) begin // Store on BRAM
                        // MAC Control Signals
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b0;
                        mac_flush   <= 1'b0;
                        
                        ReLU        <= (layer + 1'b1 < STAGE);
                    end
                    else begin // Compare and search max
                        if (temp_max_value >= max_value) begin
                            max_value <= temp_max_value;
                            if      (temp0 == temp_max_value) out_data <= output_cnt + output_cnt[1:0] - 4'h4;
                            else if (temp1 == temp_max_value) out_data <= output_cnt + output_cnt[1:0] - 4'h3;
                            else if (temp2 == temp_max_value) out_data <= output_cnt + output_cnt[1:0] - 4'h2;
                            else                              out_data <= output_cnt + output_cnt[1:0] - 4'h1;
                        end
                        // MAC Control Signals
                        mac_en      <= 1'b1;
                        mac_add     <= 1'b0;
                        mac_flush   <= 1'b0;
                        
                        ReLU        <= (layer + 1'b1 < STAGE);
                    end
                end
            endcase
        end
    end

    wire signed [7:0] temp0;
    wire signed [7:0] temp1;
    wire signed [7:0] temp2;
    wire signed [7:0] temp3;

    assign temp0 = quad_result[31:24];
    assign temp1 = quad_result[23:16];
    assign temp2 = quad_result[15:8];
    assign temp3 = quad_result[7:0];

    wire signed [7:0] temp_left; 
    wire signed [7:0] temp_right;

    assign temp_left = temp0 >= temp1 ? temp0 : temp1;
    assign temp_right = temp2 >= temp3 ? temp2 : temp3;

    wire signed [7:0] temp_max_value;

    assign temp_max_value = temp_left >= temp_right ? temp_left : temp_right;
endmodule