//==============================================================================
// File        : i2c_write_rand_tc.c
// Description : C mirror of SV random_full_seq for APB-I2C SoC testing
//==============================================================================

#include "peripheral.h"


//above should be kept in periheral.h
#define I2C_INVALID_ADDR_11    0x11
#define I2C_INVALID_ADDR_13    0x13

#define I2C_STATUS_BUSY        0x1


int main(void)
{   
     uint32_t status;
     uint32_t prdata;
     uint32_t n=1;
     uint32_t slv_addr=0xff;
     uint32_t reg_addr=0x00;
     uint32_t data_in=0x12345678;
     uint32_t i=1;
     uint32_t n_p=0;
    
     uint8_t exp_data[n];
     uint8_t act_data;

     uint32_t clk_div_value=250;

     //int idx = 0;
     uint32_t handshake_from_sv_to_c = 0;
   
     while (handshake_from_sv_to_c == 0) {
         handshake_from_sv_to_c = wait_for_handshake_from_sv();
     }
    //write
    mmio_write(I2C_BASE_ADDR + I2C_CLKDIV_OFFSET,clk_div_value);
    while (i<=n) {
    mmio_write(I2C_BASE_ADDR + I2C_SLV_ADDR_OFFSET, slv_addr);
    mmio_write(I2C_BASE_ADDR + I2C_REG_ADDR_OFFSET, reg_addr);
    mmio_write(I2C_BASE_ADDR + I2C_DATA_IN_OFFSET, data_in);
    mmio_write(I2C_BASE_ADDR + I2C_CTRL_OFFSET, 0x01);
    do {
        status = mmio_read(I2C_BASE_ADDR + I2C_STATUS_OFFSET);
       // info_print(status);
    } while ((status & I2C_STATUS_BUSY));
        exp_data[i] = (data_in >> 24) & 0xFF;
        info_print(i);
        i=i+1;
        slv_addr=slv_addr+2;
        reg_addr=reg_addr+5;
        data_in=data_in-10;
    }

    
    //read
    slv_addr=0xff;
    reg_addr=0x00;
    data_in=0x12345678;
    
    i=1;
    while (i<=n) {
    mmio_write(I2C_BASE_ADDR + I2C_SLV_ADDR_OFFSET, slv_addr);
    mmio_write(I2C_BASE_ADDR + I2C_REG_ADDR_OFFSET, reg_addr);

    mmio_write(I2C_BASE_ADDR + I2C_CTRL_OFFSET, 0x03);
    do {
        status = mmio_read(I2C_BASE_ADDR + I2C_STATUS_OFFSET);
        //info_print(status);
    } while ((status & I2C_STATUS_BUSY));

    prdata=mmio_read(I2C_BASE_ADDR + I2C_DATA_OUT_OFFSET);
    info_print(i);
    
    act_data = prdata & 0xFF;

    if (act_data == exp_data[i]) {
        info_print(0006);
        n_p=n_p+1;
    }
    else {
        info_print(0007);
    }
        slv_addr=slv_addr+2;
        reg_addr=reg_addr+5;
        data_in=data_in+10;

        i=i+1;
    }
    
    if (n == n_p) {
         info_print(9999);
     }

    send_handshake_to_sv();

}

