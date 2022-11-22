module decryption_fsm (input logic clk, input logic rst, input logic [7:0] encrypted_input, input logic [7:0] q_s, input logic shuffle_done_flag, output logic [7:0] address_s, output logic [7:0] data_s, output logic wren_s, output logic [7:0] address_d, output logic [7:0] data_d, output logic wren_d, output logic [7:0] next_enc_input_addr, output logic try_again_flag, output logic decryption_done_flag, output logic decryption_failed_flag);	

// State Encoding: {State #, wren_s, wren_d, decryption_flag, try_again_flag}
parameter [8:0] INIT                                        = 9'b00000_0000;
parameter [8:0] INC_I                                       = 9'b00001_0000;
parameter [8:0] SET_ADDR_FOR_READ_SI                        = 9'b00010_0000;
parameter [8:0] WAIT_BEFORE_READ_SI                         = 9'b00011_0000;
parameter [8:0] READ_SI                                     = 9'b00100_0000;
parameter [8:0] CALC_J                                      = 9'b00101_0000;
parameter [8:0] SET_ADDR_FOR_READ_SJ                        = 9'b00110_0000;
parameter [8:0] WAIT_BEFORE_READ_SJ                         = 9'b00111_0000;
parameter [8:0] READ_SJ                                     = 9'b01000_0000;
parameter [8:0] SET_ADDR_DATA_FOR_WRITE_SJ                  = 9'b01001_0000;
parameter [8:0] WRITE_TO_SJ                                 = 9'b01010_1000;
parameter [8:0] SET_ADDR_DATA_FOR_WRITE_SI                  = 9'b01011_0000;
parameter [8:0] WRITE_TO_SI                                 = 9'b01100_1000;
parameter [8:0] SET_ADDR_FOR_F                              = 9'b01101_0000;
parameter [8:0] WAIT_BEFORE_READ_SF                         = 9'b01110_0000;
parameter [8:0] READ_SF                                     = 9'b01111_0000;
parameter [8:0] WAIT_BEFORE_READ_ENCRYPTED_INPUT            = 9'b10000_0000;
parameter [8:0] CALC_DECRYPTED_OUTPUT                       = 9'b10001_0000;
parameter [8:0] SET_ADDR_DATA_FOR_WRITE_DO                  = 9'b10010_0000;
parameter [8:0] WRITE_DO                                    = 9'b10011_0100;
parameter [8:0] CMP_K                                       = 9'b10100_0000;
parameter [8:0] DONE                                        = 9'b10101_0010;
parameter [8:0] TRY_AGAIN                                   = 9'b10110_0001;

logic [8:0] state;
logic [4:0] k;
logic [7:0] i, j;
logic [7:0] s_i, s_j, f;
logic [7:0] decrypted_output;
logic readable_flag;

initial readable_flag = 1'b1;   // Initialize readable_flag to true
assign wren_s = state[3];
assign wren_d = state[2];
assign decryption_done_flag = state[1] & readable_flag;
assign decryption_failed_flag = state[1] & ~readable_flag;
assign try_again_flag = state[0];
assign next_enc_input_addr = {3'b000, k};

always_ff @(posedge clk) begin

    if (!rst) begin
        state <= INIT;
    end
    
    else begin
        case (state)
            INIT    :   begin
                        // Initialize addresses to 0
                        i <= 0;
                        j <= 0;
                        
                        // Remain in INIT until shuffle_memory has finished
                        if (shuffle_done_flag)
                            state <= INC_I;
                        end
                
            INC_I   :   begin   // Increment i
                        i <= i + 1'b1;
                        state <= SET_ADDR_FOR_READ_SI;
                        end
                
            SET_ADDR_FOR_READ_SI    :   begin    // Set address_s = i
                                            address_s <= i;
                                            state <= WAIT_BEFORE_READ_SI;
                                            end
    
            WAIT_BEFORE_READ_SI :   begin // Wait 1 clk before reading
                                            state <= READ_SI;
                                            end
                                    
            READ_SI :   begin // Read the data from s_mem[i], store it in s_i
                            s_i <= q_s;
                            state <= CALC_J;
                            end
                    
            CALC_J  :   begin  // Calculate j
                            j <= j + s_i;
                            state <= SET_ADDR_FOR_READ_SJ;
                        end
                    
            SET_ADDR_FOR_READ_SJ    :   begin    // Set address_s = j
                                            address_s <= j;
                                            state <= WAIT_BEFORE_READ_SJ;
                                            end
                                    
            WAIT_BEFORE_READ_SJ :   begin // Wait 1 clk before reading
                                            state <= READ_SJ;
                                            end
                                    
            READ_SJ : begin // Read the data from s_mem[j], store it in s_j
                            s_j <= q_s;
                            state <= SET_ADDR_DATA_FOR_WRITE_SJ;
                            end
                    
            SET_ADDR_DATA_FOR_WRITE_SJ  :   begin  // Set address_s = j, data_s = s_i
                                                    address_s <= j;
                                                    data_s <= s_i;
                                                    state <= WRITE_TO_SJ;
                                                    end

            WRITE_TO_SJ :   begin // Write the value of s_i into s_mem[j]
                                state <= SET_ADDR_DATA_FOR_WRITE_SI;
                                end
    
            SET_ADDR_DATA_FOR_WRITE_SI  :   begin  // Set address_s = i, data_s = s_j
                                                    address_s <= i;
                                                    data_s <= s_j;
                                                    state <= WRITE_TO_SI;
                                                    end
                                            
            WRITE_TO_SI :   begin // Write the value of s_j into s_mem[i]
                                state <= SET_ADDR_FOR_F;
                                end
                        
            SET_ADDR_FOR_F  :   begin  // Set address_s = s_i + s_j
                                    address_s <= s_i + s_j;
                                    state <= WAIT_BEFORE_READ_SF;
                                    end
                            
            WAIT_BEFORE_READ_SF :   begin // Wait 1 clk before reading
                                            state <= READ_SF;
                                            end
                                    
            READ_SF :   begin   // Read the data from s_mem[s_i+s_j], store it in f
                            f <= q_s;
                            state <= CALC_DECRYPTED_OUTPUT;
                            end

            CALC_DECRYPTED_OUTPUT   : begin   // Calculate decrypted_output
                                                decrypted_output <= f ^ encrypted_input;
                                                state <= SET_ADDR_DATA_FOR_WRITE_DO;
                                            end
                                        
            SET_ADDR_DATA_FOR_WRITE_DO : begin  // Check to see if decrypted_output = [97,122] or 32 (a-z or space)
                                                    if (!(decrypted_output >= 97 && decrypted_output <= 122) && (decrypted_output != 32)) begin
                                                        readable_flag <= 1'b0; // Set readable_flag to false if it isn't within the character range
                                                    end
                                                    // If decrypted_output is within range, readable_flag remains true
                                                    // Set address_d = k, data_d = decrypted_output
                                                    address_d <= k;
                                                    data_d <= decrypted_output;
                                                    state <= WRITE_DO;
                                                    end
    
            WRITE_DO    :   begin    // Write the value of decrypted_output to d_mem[k]
                            k <= k + 1'b1; // Increment loop counter before transition to CMP_K state 
                            state <= CMP_K;
                            end
    
            CMP_K   :   begin   // Check to see if k > 0
                        if (k > 0) begin
                            state <= INC_I;
                        end
                        // If k overflows we are done
                        else begin
                            state <= DONE;
                        end
                        end

            DONE    :   begin
                        if (readable_flag == 1'b1) begin
                            state <= DONE;  // If the decrypted_output was readable, stay in DONE
                        end
                        else begin  // Else, try again
                            state <= TRY_AGAIN;
                        end
                        end
                        
            TRY_AGAIN   :   begin   // Reset readable_flag back to true, go back to INIT
                                readable_flag <= 1'b1;
                                state <= INIT;
                            end

            default : state <= INIT;
        endcase
    end
end
	
endmodule