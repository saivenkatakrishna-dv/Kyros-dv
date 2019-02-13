//==============================================================================
// File        : i2c_write_rand_tc.c
// Description : C mirror of SV random_full_seq for APB-I2C SoC testing
//==============================================================================

#include "peripheral.h"

#define I2C_CTRL_OFFSET        0x00
#define I2C_SLV_ADDR_OFFSET    0x04
#define I2C_REG_ADDR_OFFSET    0x08
#define I2C_DATA_IN_OFFSET     0x0c
#define I2C_DATA_OUT_OFFSET    0x10
#define I2C_STATUS_OFFSET      0x14

//above should be kept in periheral.h
#define I2C_INVALID_ADDR_11    0x11
#define I2C_INVALID_ADDR_13    0x13

#define I2C_STATUS_BUSY        0x1

#define NUM_WR_RD_LOOPS        100
#define NUM_BACK_TO_BACK_LOOPS 100
#define QUEUE_DEPTH            (NUM_BACK_TO_BACK_LOOPS + 1)

static uint32_t slvaddr_q[QUEUE_DEPTH];
static uint32_t regaddr_q[QUEUE_DEPTH];
static uint32_t q_wr;
static uint32_t q_rd;

static uint32_t rand32_local(uint32_t seed)
{
    return (seed * 1103515245u) + 12345u;
}

static void queue_push(uint32_t slvaddr, uint32_t regaddr)
{
    if (q_wr < QUEUE_DEPTH) {
        slvaddr_q[q_wr] = slvaddr;
        regaddr_q[q_wr] = regaddr;
        q_wr++;
    }
}

static int queue_pop(uint32_t *slvaddr, uint32_t *regaddr)
{
    if (q_rd >= q_wr) {
        return -1;
    }

    *slvaddr = slvaddr_q[q_rd];
    *regaddr = regaddr_q[q_rd];
    q_rd++;

    return 0;
}

static void poll_i2c_not_busy(void)
{
    uint32_t status;

    do {
        status = mmio_read(I2C_BASE_ADDR + I2C_STATUS_OFFSET);
    } while ((status & I2C_STATUS_BUSY) != 0u);
}

static uint32_t next_rand(uint32_t *seed)
{
    *seed = rand32_local(*seed);
    return *seed;
}

static void i2c_write(uint32_t *seed)
{
    uint32_t slvaddr_data;
    uint32_t regaddr_data;
    uint32_t data;
    uint32_t ctrl_data;

    slvaddr_data = next_rand(seed);
    regaddr_data = next_rand(seed);
    data = next_rand(seed);
    ctrl_data = (next_rand(seed) & ~0x3u) | 0x1u;

    mmio_write(I2C_BASE_ADDR + I2C_SLV_ADDR_OFFSET, slvaddr_data);
    mmio_write(I2C_BASE_ADDR + I2C_REG_ADDR_OFFSET, regaddr_data);
    mmio_write(I2C_BASE_ADDR + I2C_DATA_IN_OFFSET, data);
    mmio_write(I2C_BASE_ADDR + I2C_CTRL_OFFSET, ctrl_data);

    queue_push(slvaddr_data & 0xffu, regaddr_data & 0xffu);
    poll_i2c_not_busy();
}

static int i2c_read(uint32_t *seed, uint32_t *prdata)
{
    uint32_t slvaddr;
    uint32_t regaddr;
    uint32_t ctrl_data;
    int ret;

    ret = queue_pop(&slvaddr, &regaddr);
    if (ret != 0) {
        return ret;
    }

    mmio_write(I2C_BASE_ADDR + I2C_SLV_ADDR_OFFSET, slvaddr);
    mmio_write(I2C_BASE_ADDR + I2C_REG_ADDR_OFFSET, regaddr);

    ctrl_data = (next_rand(seed) & ~0x3u) | 0x3u;
    mmio_write(I2C_BASE_ADDR + I2C_CTRL_OFFSET, ctrl_data);

    poll_i2c_not_busy();
    *prdata = mmio_read(I2C_BASE_ADDR + I2C_DATA_OUT_OFFSET);

    return 0;
}

static void pslver_check(void)
{
    mmio_write(I2C_BASE_ADDR + I2C_STATUS_OFFSET, 0x0);
}

int main(void)
{
    uint32_t seed = 0x12345678u;
    uint32_t prdata;
    uint32_t handshake_from_sv_to_c = 0;
    int ret;

    while (handshake_from_sv_to_c == 0u) {
        handshake_from_sv_to_c = wait_for_handshake_from_sv();
    }

    for (uint32_t i = 0; i < NUM_WR_RD_LOOPS; i++) {
        i2c_write(&seed);

        ret = i2c_read(&seed, &prdata);
        if (ret != 0) {
            return ret;
        }
    }

    for (uint32_t i = 0; i < NUM_BACK_TO_BACK_LOOPS; i++) {
        i2c_write(&seed);
    }

    for (uint32_t i = 0; i < NUM_BACK_TO_BACK_LOOPS; i++) {
        ret = i2c_read(&seed, &prdata);
        if (ret != 0) {
            return ret;
        }
    }

    mmio_write(I2C_BASE_ADDR + I2C_INVALID_ADDR_11, next_rand(&seed));
    mmio_write(I2C_BASE_ADDR + I2C_INVALID_ADDR_13, next_rand(&seed));
    pslver_check();

    send_handshake_to_sv();

    return 0;
}

