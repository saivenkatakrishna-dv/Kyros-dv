module pinmux_gpio_ss
(
//////////////////////////////////////////////////////
/////// GPIO PADS
//////////////////////////////////////////////////////
    input   logic   [16:0]  gpio_pad_in,
    output  logic   [16:0]  gpio_pad_out,
    output  logic   [16:0]  gpio_pad_oe,

//////////////////////////////////////////////////////
////// GPIO REGISTERS
//////////////////////////////////////////////////////
    input   logic   [31:0]  gpio_dir_reg,
    input   logic   [31:0]  gpio_out_reg,
    output  logic   [31:0]  gpio_in_reg,

//////////////////////////////////////////////////////
////// PINMUX REGISTERS
//////////////////////////////////////////////////////
    input   logic   [31:0]  pinmux0,
    input   logic   [31:0]  pinmux1,

//////////////////////////////////////////////////////
////// UART
//////////////////////////////////////////////////////
    input   logic           uart_tx,
    output  logic           uart_rx,

//////////////////////////////////////////////////////
//////boot
/////////////////////////////////////////////////////

    output logic            pll_clk_fail,
    output logic            rc_clk_fail,
    output logic            boot_load_done,    

//////////////////////////////////////////////////////
////// SPI
//////////////////////////////////////////////////////
    input   logic           spi_cs,
    input   logic           spi_clk,
    input   logic           spi_mosi,
    output  logic           spi_miso,

//////////////////////////////////////////////////////
////// I2C
//////////////////////////////////////////////////////
    input   logic           i2c_scl,
    input   logic           i2c_sda_out,
    input   logic           i2c_sda_oe,
    output  logic           i2c_sda_in,

//////////////////////////////////////////////////////
////// INTERRUPT
//////////////////////////////////////////////////////
    output  logic   [16:0]  irq_in,

//////////////////////////////////////////////////////
////// DEBUG
//////////////////////////////////////////////////////
    input   logic           clk_out,
    input   logic   [15:0]  debug,

//////////////////////////////////////////////////////
////// TRACE
//////////////////////////////////////////////////////
    input   logic           atclk,
    input   logic           atvalid,
    input   logic           atready,
    input   logic           atsync,

    input   logic   [2:0]   atid,
    input   logic   [15:0]  atdata

);

////////////////////////////////////////////////////////
// PINMUX FUNCTION ENUM
////////////////////////////////////////////////////////

typedef enum logic [2:0]
{   
    PINMUX_GPIO       = 3'd0,
    PINMUX_PERIPHERAL = 3'd1,
    PINMUX_IRQ        = 3'd2,
    PINMUX_DEBUG      = 3'd3,
    PINMUX_TRACE      = 3'd4
} pinmux_func_e;

////////////////////////////////////////////////////////
// FUNCTION SELECT
////////////////////////////////////////////////////////

pinmux_func_e func_sel [16:0];

////////////////////////////////////////////////////////
// PINMUX DECODE
////////////////////////////////////////////////////////

always_comb
begin
    
     func_sel[0]  = pinmux_func_e'(pinmux0[2:0]);
     func_sel[1]  = pinmux_func_e'(pinmux0[5:3]);
     func_sel[2]  = pinmux_func_e'(pinmux0[8:6]);
     func_sel[3]  = pinmux_func_e'(pinmux0[11:9]);
     func_sel[4]  = pinmux_func_e'(pinmux0[14:12]);
     func_sel[5]  = pinmux_func_e'(pinmux0[17:15]);
     func_sel[6]  = pinmux_func_e'(pinmux0[20:18]);
     func_sel[7]  = pinmux_func_e'(pinmux0[23:21]);
     func_sel[8]  = pinmux_func_e'(pinmux0[26:24]);
     func_sel[9]  = pinmux_func_e'(pinmux0[29:27]);
                                                   
     func_sel[10] = pinmux_func_e'(pinmux1[2:0]);
     func_sel[11] = pinmux_func_e'(pinmux1[5:3]);
     func_sel[12] = pinmux_func_e'(pinmux1[8:6]);
     func_sel[13] = pinmux_func_e'(pinmux1[11:9]);
     func_sel[14] = pinmux_func_e'(pinmux1[14:12]);
     func_sel[15] = pinmux_func_e'(pinmux1[17:15]);
     func_sel[16] = pinmux_func_e'(pinmux1[20:18]);

end

////////////// GPIO MUX LOGIC /////////////////////////

always_comb begin

    gpio_pad_out     = 17'h0;
    gpio_pad_oe      = 17'h0;
    gpio_in_reg      = 32'h0;   // output is declared but not sending any data 
    uart_rx          = 1'b0;
    spi_miso         = 1'b0;
    i2c_sda_in       = 1'b0;
    irq_in           = 17'h0;
    rc_clk_fail      = 1'b0;  // need to conform default value 
    pll_clk_fail     = 1'b0;  // need to conform default value 
    boot_load_done   = 1'b0;  // need to conform default value 
    
/////////////////////////////////////////////////////////
//////////  GPIO0 MUX
/////////////////////////////////////////////////////////

     case(func_sel[0])

        PINMUX_GPIO:
        if (gpio_dir_reg[0]) begin

            gpio_pad_out[0] = gpio_out_reg[0];
            gpio_pad_oe [0] = gpio_dir_reg[0];
            end

            else 
                gpio_in_reg[0] = gpio_pad_in[0];

        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[0] = uart_tx;
            gpio_pad_oe [0] = 1'b1;
        end

        PINMUX_IRQ:
            irq_in[0] = gpio_pad_in[0];

        PINMUX_DEBUG:
        begin
            gpio_pad_out[0] = clk_out;
            gpio_pad_oe [0] = 1'b1;
        end

        PINMUX_TRACE:
        begin
            gpio_pad_out[0] = atclk;
            gpio_pad_oe [0] = 1'b1;
        end

    endcase

/////////////////////////////////////////////////////////
//////////  GPIO1 MUX
/////////////////////////////////////////////////////////


     case(func_sel[1])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[1]) begin
            gpio_pad_out[1] = gpio_out_reg[1];
            gpio_pad_oe [1] = gpio_dir_reg[1]; 
            end

            else 
                gpio_in_reg[1] = gpio_pad_in[1];
                    
        PINMUX_PERIPHERAL:
            uart_rx = gpio_pad_in[1];
    
        PINMUX_IRQ:
            irq_in[1] = gpio_pad_in[1];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[1] = debug[0];
            gpio_pad_oe [1] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[1] = atvalid;
            gpio_pad_oe [1] = 1'b1;
        end

    endcase

/////////////////////////////////////////////////////////
//////////  GPIO2 MUX
/////////////////////////////////////////////////////////

     case(func_sel[2])

        PINMUX_GPIO:
        if (gpio_dir_reg[2]) begin
            gpio_pad_out[2] = gpio_out_reg[2];
            gpio_pad_oe [2] = gpio_dir_reg[2]; 
            end

            else 
                gpio_in_reg[2] = gpio_pad_in[2];

        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[2] = spi_mosi;
            gpio_pad_oe [2] = 1'b1;
        end

        PINMUX_IRQ:
            irq_in[2] = gpio_pad_in[2];

        PINMUX_DEBUG:
        begin
            gpio_pad_out[2] = debug[1];
            gpio_pad_oe [2] = 1'b1;
        end

        PINMUX_TRACE:
        begin
            gpio_pad_out[2] = atready;
            gpio_pad_oe [2] = 1'b1;
        end

    endcase

/////////////////////////////////////////////////////////
//////////  GPIO3 MUX
/////////////////////////////////////////////////////////

     case(func_sel[3])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[3]) begin
            gpio_pad_out[3] = gpio_out_reg[3];
            gpio_pad_oe [3] = gpio_dir_reg[3]; 
            end

            else 
                gpio_in_reg[3] = gpio_pad_in[3];
   
        PINMUX_PERIPHERAL:
            spi_miso = gpio_pad_in[3];
    
        PINMUX_IRQ:
            irq_in[3] = gpio_pad_in[3];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[3] = debug[2];
            gpio_pad_oe [3] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[3] = atsync;
            gpio_pad_oe [3] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO4 MUX
/////////////////////////////////////////////////////////

     case(func_sel[4])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[4]) begin
            gpio_pad_out[4] = gpio_out_reg[4];
            gpio_pad_oe [4] = gpio_dir_reg[4]; 
            end

            else 
                gpio_in_reg[4] = gpio_pad_in[4];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[4] = spi_clk;
            gpio_pad_oe [4] = 1'b1;
        end
    
        PINMUX_IRQ:
            irq_in[4] = gpio_pad_in[4];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[4] = debug[3];
            gpio_pad_oe [4] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[4] = atid[0];
            gpio_pad_oe [4] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO5 MUX
/////////////////////////////////////////////////////////

     case(func_sel[5])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[5]) begin
            gpio_pad_out[5] = gpio_out_reg[5];
            gpio_pad_oe [5] = gpio_dir_reg[5]; 
            end

            else 
                gpio_in_reg[5] = gpio_pad_in[5];
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[5] = spi_cs;
            gpio_pad_oe [5] = 1'b1;
        end
    
        PINMUX_IRQ:
            irq_in[5] = gpio_pad_in[5];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[5] = debug[4];
            gpio_pad_oe [5] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[5] = atid[1];
            gpio_pad_oe [5] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO6 MUX
/////////////////////////////////////////////////////////

     case(func_sel[6])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[6]) begin
            gpio_pad_out[6] = gpio_out_reg[6];
            gpio_pad_oe [6] = gpio_dir_reg[6]; 
            end

            else 
                gpio_in_reg[6] = gpio_pad_in[6];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[6] = i2c_sda_out;
            gpio_pad_oe [6] = i2c_sda_oe;
        end
    
        PINMUX_IRQ:
            irq_in[6] = gpio_pad_in[6];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[6] = debug[5];
            gpio_pad_oe [6] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[6] = atid[2];
            gpio_pad_oe [6] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO7 MUX
/////////////////////////////////////////////////////////

     case(func_sel[7])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[7]) begin
            gpio_pad_out[7] = gpio_out_reg[7];
            gpio_pad_oe [7] = gpio_dir_reg[7]; 
            end

            else 
                gpio_in_reg[7] = gpio_pad_in[7];
   
        PINMUX_PERIPHERAL:
            i2c_sda_in = i2c_scl;
    
        PINMUX_IRQ:
            irq_in[7] = gpio_pad_in[7];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[7] = debug[6];
            gpio_pad_oe [7] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[7] = atdata[0];
            gpio_pad_oe [7] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO8 MUX
/////////////////////////////////////////////////////////

     case(func_sel[8])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[8]) begin
            gpio_pad_out[8] = gpio_out_reg[8];
            gpio_pad_oe [8] = gpio_dir_reg[8]; 
            end

            else 
                gpio_in_reg[8] = gpio_pad_in[8];
  
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[8] = gpio_out_reg[8];
            gpio_pad_oe [8] = 1'b1;
        end
    
        PINMUX_IRQ:
            irq_in[8] = gpio_pad_in[8];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[8] = debug[7];
            gpio_pad_oe [8] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[8] = atdata[1];
            gpio_pad_oe [8] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO9 MUX
/////////////////////////////////////////////////////////

     case(func_sel[9])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[9]) begin
            gpio_pad_out[9] = gpio_out_reg[9];
            gpio_pad_oe [9] = gpio_dir_reg[9]; 
            end

            else 
                pll_clk_fail = gpio_pad_in[9];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[9] = gpio_out_reg[9];
            gpio_pad_oe [9] = gpio_dir_reg[9];
        end
    
        PINMUX_IRQ:
            irq_in[9] = gpio_pad_in[9];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[9] = debug[8];
            gpio_pad_oe [9] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[9] = atdata[2];
            gpio_pad_oe [9] = 1'b1;
        end
    
    endcase


/////////////////////////////////////////////////////////
//////////  GPIO10 MUX
/////////////////////////////////////////////////////////
    
     case(func_sel[10])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[10]) begin
            gpio_pad_out[10] = gpio_out_reg[10];
            gpio_pad_oe [10] = gpio_dir_reg[10]; 
            end

            else 
                rc_clk_fail = gpio_pad_in[10];

    
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[10] = gpio_out_reg[10];
            gpio_pad_oe [10] = gpio_dir_reg[10];
        end
    
        PINMUX_IRQ:
            irq_in[10] = gpio_pad_in[10];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[10] = debug[9];
            gpio_pad_oe [10] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[10] = atdata[3];
            gpio_pad_oe [10] = 1'b1;
        end
    
    endcase


/////////////////////////////////////////////////////////
//////////  GPIO11 MUX
/////////////////////////////////////////////////////////

     case(func_sel[11])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[11]) begin
            gpio_pad_out[11] = gpio_out_reg[11];
            gpio_pad_oe [11] = gpio_dir_reg[11]; 
            end

            else 
                boot_load_done = gpio_pad_in[11];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[11] = gpio_out_reg[11];
            gpio_pad_oe [11] = gpio_dir_reg[11];
        end
    
        PINMUX_IRQ:
            irq_in[11] = gpio_pad_in[11];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[11] = debug[10];
            gpio_pad_oe [11] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[11] = atdata[4];
            gpio_pad_oe [11] = 1'b1;
        end
    
    endcase


/////////////////////////////////////////////////////////
//////////  GPIO12 MUX
/////////////////////////////////////////////////////////

     case(func_sel[12])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[12]) begin
            gpio_pad_out[12] = gpio_out_reg[12];
            gpio_pad_oe [12] = gpio_dir_reg[12]; 
            end

            else 
                gpio_in_reg[12] = gpio_pad_in[12];

        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[12] = gpio_out_reg[12];
            gpio_pad_oe [12] = gpio_dir_reg[12];
        end
    
        PINMUX_IRQ:
            irq_in[12] = gpio_pad_in[12];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[12] = debug[11];
            gpio_pad_oe [12] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[12] = atdata[5];
            gpio_pad_oe [12] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO13 MUX
/////////////////////////////////////////////////////////

     case(func_sel[13])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[13]) begin
            gpio_pad_out[13] = gpio_out_reg[13];
            gpio_pad_oe [13] = gpio_dir_reg[13]; 
            end

            else 
                gpio_in_reg[13] = gpio_pad_in[13];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[13] = gpio_out_reg[13];
            gpio_pad_oe [13] = gpio_dir_reg[13];
        end
    
        PINMUX_IRQ:
            irq_in[13] = gpio_pad_in[13];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[13] = debug[12];
            gpio_pad_oe [13] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[13] = atdata[6];
            gpio_pad_oe [13] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO14 MUX
/////////////////////////////////////////////////////////

     case(func_sel[14])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[14]) begin
            gpio_pad_out[14] = gpio_out_reg[14];
            gpio_pad_oe [14] = gpio_dir_reg[14]; 
            end

            else 
                gpio_in_reg[14] = gpio_pad_in[14];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[14] = gpio_out_reg[14];
            gpio_pad_oe [14] = gpio_dir_reg[14];
        end
    
        PINMUX_IRQ:
            irq_in[14] = gpio_pad_in[14];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[14] = debug[12];
            gpio_pad_oe [14] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[14] = atdata[6];
            gpio_pad_oe [14] = 1'b1;
        end
    
    endcase

/////////////////////////////////////////////////////////
//////////  GPIO15 MUX
/////////////////////////////////////////////////////////

     case(func_sel[15])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[15]) begin
            gpio_pad_out[15] = gpio_out_reg[15];
            gpio_pad_oe [15] = gpio_dir_reg[15]; 
            end

            else 
                gpio_in_reg[15] = gpio_pad_in[15];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[15] = gpio_out_reg[15];
            gpio_pad_oe [15] = gpio_dir_reg[15];
        end
    
        PINMUX_IRQ:
            irq_in[15] = gpio_pad_in[15];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[15] = debug[14];
            gpio_pad_oe [15] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[15] = gpio_out_reg[15];
            gpio_pad_oe [15] = gpio_dir_reg[15];
        end
    
    endcase
/////////////////////////////////////////////////////////
//////////  GPIO16 MUX
/////////////////////////////////////////////////////////

     case(func_sel[16])
    
        PINMUX_GPIO:
        if (gpio_dir_reg[16]) begin
            gpio_pad_out[16] = gpio_out_reg[16];
            gpio_pad_oe [16] = gpio_dir_reg[16]; 
            end

            else 
                gpio_in_reg[16] = gpio_pad_in[16];
   
        PINMUX_PERIPHERAL:
        begin
            gpio_pad_out[16] = gpio_out_reg[16];
            gpio_pad_oe [16] = gpio_dir_reg[16];
        end
    
        PINMUX_IRQ:
            irq_in[16] = gpio_pad_in[16];
    
        PINMUX_DEBUG:
        begin
            gpio_pad_out[16] = debug[15];
            gpio_pad_oe [16] = 1'b1;
        end
    
        PINMUX_TRACE:
        begin
            gpio_pad_out[16] =  gpio_out_reg[16];
            gpio_pad_oe [16] =  gpio_dir_reg[16];
        end
    
    endcase


end

endmodule
