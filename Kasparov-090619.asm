module verificator(input logic clk,
input logic rst,
input logic [31:0] slave_error_counter,
inout tri [31:0] data_line,
output logic clk_out,
output logic [31:0] error_counter,
output logic rdwr);

logic [31:0] clk_counter;
logic [31:0] data_counter;
logic [31:0] data;
logic control;
logic [15:0] state;
assign data_line = control ? data : 'z;

// creating sync clk for slave fpga @(posedge clk or posedge rst) begin
    if(rst) begin
        clk_out <= 0;
        clk_counter <= 0;
    end
    else begin
        clk_counter = clk_counter + 1;
        if(clk_counter >= 10) begin
            clk_counter <= 0;
            clk_out <= ~clk_out;
        end
    end
end

//creating data signal for slave fpga always @(posedge clk_out or posedge rst) begin
    if(rst) begin
        data_counter = 0;
        control = 1;
        data = 0;
        state = 1;
        error_counter = 0;
        rdwr = 0;
    end
    
    else begin
        case (state)
            1: begin    // start writing to port
                    data_counter = data_counter + 1;
                    control = 1;
                    rdwr = 0;
                    data = data_counter;
                    state = 2;
                end
            2: begin    // start reading from port
                    control = 0;
                    rdwr = 1;
                    state = 3;
                end
            3: begin    //  validate data from port
                    if(data_line != data_counter) 
                        error_counter = error_counter + 1;
                    //rdwr = 0;
                    state = 4;
                end
            4:	begin
                    rdwr = 0;
                    state = 1;
                end
            default:;
        endcase
    end
end

endmodule

module verificator_slave(input logic clk,
input logic clk_out,
input logic rst,
input logic rdwr,
inout tri [31:0] data_line,
output logic [31:0] slave_error);

logic control, data_counter_flag;
logic [15:0] state;
logic [31:0] error_counter, data_aquired, data, data_counter;

logic drdwr, dclk_out;
always @(posedge clk) begin
    drdwr <= rdwr;
    dclk_out <= clk_out;
end

always @(posedge dclk_out or posedge rst) begin
    if(rst) begin
        control = 0;
        data_aquired = 0;
        state = 2;
        slave_error = 0;
        data_counter = 0;
        data_counter_flag = 0;
    end
    
    else begin
        if(drdwr == 0) begin
            data_counter_flag = 1;
            case (state)
            1: begin
                control = 0;
                state = 2;
                end
            2: begin
                    data = data_line;
                state = 1;
                end
            default:;
            endcase
        end
        else if (drdwr) begin
            state = 1;
            if(data_counter_flag) begin
                data_counter_flag = 0;
                data_counter = data_counter + 1;
                
                if (data != data_counter)
                    slave_error = slave_error + 1;
            end
            control = 1;
        end
    end
end

endmodule