# ============================================================
# KyroSoC Full Makefile (RTL + RISC-V SW + Simulation)
# Tool: Cadence Xcelium (irun)
# Arch: RV32IMC
# ============================================================


# =========================================================
# PHONY
# =========================================================
.PHONY: all gen build spike rtl compare clean dirs

# =========================================================
# RANDOM SEED + MODE
# =========================================================
SEED := $(or $(SEED),$(shell od -An -N2 -tu2 < /dev/urandom | tr -d ' '))
MODE ?= base

PREFIX = $(MODE)_$(SEED)

# =========================================================
# ROOT (FROM sim)
# =========================================================
ROOT     = /home/$(USER)/Desktop/pinaka
RISCV_DV = $(ROOT)/third_party/riscv-dv
SW_DIR   = $(ROOT)/sw
RTL_DIR  = $(ROOT)/rtl
SIM_DIR  = $(ROOT)/sim
RESULT_DIR = $(SIM_DIR)/results
SCRIPT_DIR = $(SIM_DIR)/scripts

USER_EXT = $(RISCV_DV)/user_extension

RTL_SRC = $(ROOT)/rtl/top

LOG_DIR = $(RESULT_DIR)/logs/$(PREFIX)



# =========================================================
# ISA (FULL DEFAULT - IMPORTANT)
# =========================================================
ISA ?= RV32I,RV32M,RV32C,RV32F,RV32FC,RV32D,RV32DC,RV32A

# GCC ARCH (separate from ISA)
ARCH = -march=rv32iac

#ARCH = -march=rv32imafdc
ABI  = -mabi=ilp32

# =========================================================
# MODE FLAGS (CONTROL INSTR, NOT ISA)
# =========================================================

ifeq ($(MODE),base)
GEN_MODE_FLAGS = \
+instr_cnt=10000 \
+disable_compressed_instr=1 \
+disable_mul_div_instr=1 \
+disable_floating_point_instr=1 \
+enable_amo=0 \
+no_amo_instr=1 \
+no_compressed_instr=1 \
+no_csr_instr=1 \
+no_fence_instr=1 \
+no_system_instr=1 \
+disable_instr=fence \
+disable_instr=fence_i

else ifeq ($(MODE),atomic)
GEN_MODE_FLAGS = \
+isa=rv32a \
+instr_cnt=1000 \
+bare_program_mode=1 \
+enable_amo=1 \
+disable_compressed_instr=1 \
+disable_mul_div_instr=1 \
+disable_floating_point_instr=1 \
+no_branch_jump=1 \
+no_csr_instr=1 \
+no_load_store=1 \
+no_alu_instr=1 \
+cfg_disable_compressed_instr=1 \
+directed_instr_0=riscv_amo_instr_stream,1000 \
+directed_instr_1=riscv_lr_sc_instr_stream,1000 \
+num_of_sub_program=0


else ifeq ($(MODE),comp)
GEN_MODE_FLAGS = \
+isa=rv32c \
+instr_cnt=10000 \
+bare_program_mode=1 \
+enable_compressed_instr=1 \
+disable_compressed_instr=0 \
+enable_amo=0 \
+disable_mul_div_instr=1 \
+disable_floating_point_instr=1 \
+no_branch_jump=1 \
+no_load_store=1 \
+no_csr_instr=1 \
+no_system_instr=1 \
+no_data_page=1 \
+no_stack=1 \
+force_compressed_instr=1

endif

# =========================================================
# TOOLCHAIN
# =========================================================
RISCV_PREFIX  = /opt/riscv64im/bin/riscv64-unknown-elf
RISCV_GCC     = $(RISCV_PREFIX)-gcc
RISCV_OBJDUMP = $(RISCV_PREFIX)-objdump
RISCV_OBJCOPY = $(RISCV_PREFIX)-objcopy

CFLAGS = $(ARCH) $(ABI) -O0 -static -nostdlib

LINKER = $(SCRIPT_DIR)/linker.ld

# =========================================================
# FILES
# =========================================================
ASM_FILE = $(SW_DIR)/$(PREFIX).S
SEED_DIR = $(RESULT_DIR)/$(PREFIX)

ELF = $(SEED_DIR)/$(PREFIX).elf
BIN = $(SEED_DIR)/$(PREFIX).bin

UVM_LOG   = $(LOG_DIR)/$(PREFIX)_uvm.log
SPIKE_LOG = $(LOG_DIR)/$(PREFIX)_spike.log
RTL_LOG   = $(LOG_DIR)/$(PREFIX)_rtl.log
CMP_LOG   = $(LOG_DIR)/$(PREFIX)_compare.log

# =========================================================
# DEFAULT FLOW
# =========================================================
all: dirs gen build spike rtl compare

# =========================================================
# DIR SETUP
# =========================================================
dirs:
	mkdir -p $(SW_DIR)
	mkdir -p $(RESULT_DIR)
	mkdir -p $(LOG_DIR)

# =========================================================
# 1. GENERATION (riscv-dv)
# =========================================================
gen:
	@echo "========== GENERATION =========="
	@echo "MODE = $(MODE)"
	@echo "SEED = $(SEED)"
	@echo "ISA  = $(ISA)"

	mkdir -p $(SEED_DIR)

	
	cd $(RISCV_DV) && \
	xrun -64bit -sv -uvm \
	+svseed=random \
	+asm_file_name=$(PREFIX) \
	+march=$(ISA) \
	-uvmhome /tools/cadence_march2021/XCELIUM2009/tools/methodology/UVM/CDNS-1.2 \
	-f $(ROOT)/sim/cfg/files.f \
	-top riscv_instr_gen_tb_top \
	+UVM_TESTNAME=riscv_instr_base_test \
	+gen_only=1 \
	+bare_program_mode=1 \
	$(GEN_MODE_FLAGS) \
	+ntb_random_seed=random \
	-access +rwc \
	-l $(UVM_LOG)

	# Move ASM to sw/
	@if [ -f $(RISCV_DV)/$(PREFIX).S ]; then \
		mv $(RISCV_DV)/$(PREFIX).S $(SW_DIR)/; \
		echo "? ASM moved to sw/"; \
	else \
		echo "? ERROR: ASM not generated"; exit 1; \
	fi

# =========================================================
# 2. BUILD
# =========================================================
build:
	@echo "========== BUILD =========="

	@if [ ! -f $(ASM_FILE) ]; then \
		echo "ERROR: ASM missing"; exit 1; \
	fi

	mkdir -p $(SEED_DIR)

	cp $(ASM_FILE) $(SEED_DIR)/

	$(RISCV_GCC) \
    $(ASM_FILE) \
    $(USER_EXT)/user_init.s \
    $(CFLAGS) \
    -I$(USER_EXT) \
    -T $(LINKER) \
    -o $(ELF)

	$(RISCV_OBJDUMP) -d $(ELF) > $(SEED_DIR)/$(PREFIX).objdump

	$(RISCV_OBJCOPY) -O binary $(ELF) $(BIN)

	# HEX generation
	$(RISCV_OBJCOPY) -O binary --only-section=.text $(ELF) $(SEED_DIR)/text.bin

	xxd -p -c 4 $(SEED_DIR)/text.bin | \
	sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' > $(SEED_DIR)/$(PREFIX)_instr.hex

	cd $(SEED_DIR) && python $(SCRIPT_DIR)/split_hex.py $(PREFIX)_instr.hex



# =========================================================
# 3. SPIKE
# =========================================================
spike:
	@echo "========== SPIKE =========="

	env LD_LIBRARY_PATH=$(HOME)/gcc-10-install/lib64:$$LD_LIBRARY_PATH \
	~/riscv-isa-sim/build/spike --log-commits --isa=RV32IAC $(ELF) \
	> $(SPIKE_LOG) 2>&1


# =========================================================
# 4. RTL
# =========================================================
rtl:
	@echo "========== RTL =========="

	xrun -64bit -sv \
	-f cfg/rtl.f \
	-f cfg/tb.f \
	-access +rwc \
	+instr_file_B0=$(SEED_DIR)/instruction_mem_B0.hex \
	+instr_file_B1=$(SEED_DIR)/instruction_mem_B1.hex \
	+instr_file_B2=$(SEED_DIR)/instruction_mem_B2.hex \
	+instr_file_B3=$(SEED_DIR)/instruction_mem_B3.hex \
	-l $(RTL_LOG)
	
	
# =========================================================
# 5. COMPARE
# =========================================================
compare:
	@echo "========== COMPARE =========="

	python $(SCRIPT_DIR)/comapare_atomic.py \
	$(SPIKE_LOG) $(RTL_LOG) | tee $(CMP_LOG)


	@echo "TEST = $(PREFIX)"
	@echo "ISA  = $(ISA)"
	

# =========================================================
# CLEAN
# =========================================================
clean:
	rm -f $(RTL_DIR)/instruction_mem_B*.hex
	rm -f $(RTL_DIR)/*.log  
	rm -f $(RTL_DIR)/xrun.history


# ============================================================
# Help (Updated)
# ============================================================

.PHONY: help
help:
	@echo "===================================================="
	@echo " KyroSoC Makefile Help"
	@echo "===================================================="
	@echo ""
	@echo "Simulation:"
	@echo " make run TEST=<test> SEED=<seed>"
	@echo " make gui TEST=<test>"
	@echo ""
	@echo "RISC-V Build:"
	@echo " make sw_build PROG=<name>"
	@echo ""
	@echo "Run with SW:"
	@echo " make run_sw PROG=<name> TEST=<test>"
	@echo " make run_hex PROG=<name> TEST=<test>"
	@echo ""
	@echo "Regression:"
	@echo " make regress"
	@echo ""
	@echo "Clean:"
	@echo " make clean"
	@echo " make distclean"
	@echo ""
	@echo "Variables:"
	@echo " TEST         = $(TEST)"
	@echo " SEED         = $(SEED)"
	@echo " PROG         = $(PROG)"
	@echo " RISCV_ARCH   = $(RISCV_ARCH)"
	@echo " RISCV_ABI    = $(RISCV_ABI)"
	@echo ""
	@echo "Examples:"
	@echo " make run TEST=basic_test"
	@echo " make run_sw PROG=hello TEST=core_test"
	@echo " make run_hex PROG=hello"
	@echo "===================================================="
