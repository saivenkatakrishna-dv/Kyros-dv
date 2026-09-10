//------------------------------------------------------------------------------
// Company  : KYROS SEMI PVT LTD
// Designer : Deekshith H P
// Date     : 03-09-2026
// Design   : DATA_INTERFACE_TX2_MAIN
//------------------------------------------------------------------------------

module DATA_INTERFACE_TX2_MAIN#(parameter logic [7:0] IN_WIDTH = 20,
                                parameter logic [7:0] OUT_WIDTH = 10,
                                parameter logic [4:0] SYMBOL   = IN_WIDTH/OUT_WIDTH
                                )
                               ( input  logic                i_pclk,
                                 input  logic                i_rst_n,
                                 input  logic [IN_WIDTH-1:0] i_Tx_data2,
                              //   input  logic [2:0]          i_Width,
                                 input  logic                enable,
                                 input  logic                i_data_valid2,
                                 output logic [9:0]          o_Tx_data2
                                 );


//logic [3:0] symbol_reg  ;

//assign symbol_reg = i_Width ;

logic [1:0] counter_temp ;

    always@(posedge i_pclk or negedge i_rst_n)
           begin
            if(!i_rst_n)
                begin
                counter_temp <= 2'b00;
                end
            else
                begin
                if(enable && i_data_valid2 )
                    begin
                        if(counter_temp == SYMBOL-1)
                            begin
                            counter_temp <= 2'b00;
                            end
                        else
                            begin
                            counter_temp <= counter_temp + 2'b01;
                            end
                   end
                   else
                       begin
                       counter_temp <= 2'b00;
                       end
                 end
           end

logic [9:0] o_reg_temp ;

     always@(posedge i_pclk or negedge i_rst_n)
        begin
        if(!i_rst_n)
            begin
                o_reg_temp <= 10'd0;
            end
        else
            begin

                 if(enable)
                        begin
                    case(SYMBOL)
                 4'd1    : begin
                            case(counter_temp)
                                 2'b0 : o_reg_temp <= i_Tx_data2[9:0] ;
                                 default :  o_reg_temp <= 10'd0;

                            endcase
                           end

                 4'd2    : begin
                            case(counter_temp)
                                2'b00        :  o_reg_temp <= i_Tx_data2[9:0]   ;
                                2'b01        :  o_reg_temp <= i_Tx_data2[19:10] ;
                                default :  o_reg_temp <= 10'd0;
                           endcase
                           end
             /*   4'd3    : begin
                            case(counter_temp)
                                2'b00        :  o_reg_temp <= i_Tx_data2[9:0]   ;
                                2'b01        :  o_reg_temp <= i_Tx_data2[19:10] ;
                                2'b10        :  o_reg_temp <= i_Tx_data2[29:20] ;
                           endcase
                           end*/
               4'd4    : begin
                            case(counter_temp)
                                2'b00        :  o_reg_temp <= i_Tx_data2[9:0]   ;
                                2'b01        :  o_reg_temp <= i_Tx_data2[19:10] ;
                                2'b10        :  o_reg_temp <= i_Tx_data2[29:20] ;
                                2'b11        :  o_reg_temp <= i_Tx_data2[39:30] ;
                                default :  o_reg_temp <= 10'd0;
                           endcase
                           end
                    endcase
                end
                else
                    begin
                        o_reg_temp <= 10'd0;
                    end
          end
        end

    assign o_Tx_data2 = o_reg_temp ;

 endmodule
