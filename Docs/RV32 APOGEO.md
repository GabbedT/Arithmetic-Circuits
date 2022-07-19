# RV32 APOGEO

# Features

    * Configurable for FPGA and ASIC
    * Cache 
    * Asyncronous or syncronous reset
    * AXI interface
    * Floating Point Unit


* Low power
* I - M - [F - D] - Zicsr - Zifencei - C - B(not full) 
 * Dense code with C, B, A ext 

* FPU [optional] (software disable for power consumption)
* Multiplier [sequential / pipelined - different latency] 
* Non maskable interrupt (NMI)
* Interrupt pin (INTRQ)
* L1 Cache separated (2 * 16kB) (software disable)
* 7 Stages pipeline (FTCH - ITAG - DECD - EXCT - (MEM - DTAG) - WRBK)
* AXI-lite interface (64 bit)
* Sleep unit
* Clock gating on FPU and Cache for power consumption
* Branch Predictor
* Return Address Stack
* Timers and Watchdog timer
* Performance counters (L1 cache miss, FP instruction retired)



# Cache System

## Instruction cache

Instruction cache accesses are mostly sequentials (PC + 4 or PC + 2), thus the CPU will benefit accessing a single block with multiple word inside: high block size will be the better choice here. To reduce power consumption low associativity is used because of it's reduced hardware complexity. Early restart mode is used.

* 256 bits (32 Bytes) block size: supply instruction fetch unit of 8 instructions per access
* 2-way associative: reduce power consumption
* 16kB total size
* Early restart mode: when a miss occours, the first block is supplied to the fetch unit, then the block is written into the cache and later read 
* 4 banks


Address to access the I$:  

* [3:0]   To select the word in the block (Block offset) (Not used in addressing)
* [12:4]  To select the cache line (Actual address)
* [32:13] To compare with the rest of address (Tag) (Not used in addressing)

After supplying the address the data will be written/read after 1 clock cycle


## Data cache system

Data cache acesses unlike instruction cache may be sparse, this will lead to index conflicts: thus the CPU will benefit with the use of a high associativity organization. The data cache is splitted into 2 different banks selected by a low order bit to lower the power consumption (less memory accessed) and speed (lower recover time from a read). Early restart mode is used, write back to reduce bandwidth usage, write no allocate. To support the pipeline speed a write buffer is used giving priority to reads.

* 128 bits (16 bytes) block size 
* 2-Way Associative Cache: for lowering miss rate
* 16kB total size
* Byte write granularity
* 4 banks: for lowering power consumption and speed
* Early restart mode: the first block is supplied to the memory unit, then the block is written into the cache and later read
* Write back: keep a dirty bit, on block replacement, write that block into memory
* Write no allocate: in case of write miss, write directly the word in memory (save complexity and power)
* Write buffer: to give read priority over write
* Flushable (Write back all the data)
* I/O data must not acccess the cache

A flush happens when a dirty data is replaced (local flush) or when the flush pin get asserted / fence instruction get executed (global flush)

After supplying the address the data will be written/read after 1 clock cycle
On reads the word is supplied

Address to acces the D$:

* [1:0]   To align the word (Not used)
* [2]     To select the word in the block (Block offset) (Not used in addressing)
* [3]     To select a way (Index) (Not used in addressing)
* [18:4]  To select the cache line (Actual address)
* [32:19] To compare with the rest of address (Tag) (Not used in addressing)


On miss the AXI interface will supply the cache system of the needed block. Data and instruction block is supplied in two / four AXI beats (64 bit). If instruction cache miss, then the first beat will be send first to FETCH UNIT and then stored in cache with the second beat. The second beat can later be loaded.


# Pipeline description

IAS - IWS - DEC - EXE - DAS - DWS - WBK

## Instruction Address Supply

### General behaviour

The IAS is the first stage of accessing the cache, it deliver the computed address to the I$ to access memory and resolve branch with a branch predictor (GSHARE). It also implement a RAS (Return Address Stack) to speedup routine returns and a BTB of 128 entries.

In this stage is situated the PC, the output is taken as input by a 2-1 multiplexer (the other input is the address supplied by the decoder), the branch predictor then delivers a bit that select the outcome (taken -> DECODER_ADDR   not taken -> PC_ADDR) (the bit is also saved to compare with the branch resolve). If the branch is taken, the PC is saved in another register while the actual PC is loaded with the BRANCH_ADDRESS + 4, because BRANCH_ADDRESS is already been delivered to I$. PC could be incremented by 2 if a compressed instruction is executed.

To lower the power consumption the BTB (which gave the PC the next address) is accessed only if the instruction that is going into the DECODE stage (currently in IWS stage) is a branch and the branch is actually taken. So when the instruction is a branch, the GSHARE predictor is accessed and depending on the taken bit the BTB is then accessed, the next PC is delivered to the I$ system and PC is updated. If predicted correctly this will give a 0 cycles delay branch instead of 1 (decode says if it's a branch and supplies the BTA). 

Then the branch is resolved in the EXECUTE stage: if the prediction is right then no harm is done and everything can continue. But if the prediction is wrong then: the PC needs to be reloaded with the old PC and the instructions supplied to ITAG need to be flushed. Basically: 

* If we jumped
    * If correct: flush the instruction in DECODE (NOP)
    * If not: let the instruction in DECODE execute, change shift register with the preceeding instructions and load PC
* If we didn't jump
    * If correct: do nothing
    * If not: load PC, flush DECODE and stall ITAG

The address supplied to the cache is: [18:4], the IAS will fetch the entire cache block. The selection of the right word is then done by ITAG based on current PC (the N instruction after the PC should be fetched).
Fetching happens when:
    * Instruction buffer is half empty or less
    * A branch is taken
  
The IFU also check eventual misaligned memory access (exception)

In case of instruction miss, if the miss happens during the fetch of a branching instruction, then the IAS and IWS must be stalled and wait for memory. If the miss happens during normal execution the pipeline flows normally until the instruction buffer is empty, if during this time there is a branch on executing instructions, the pipeline is stalled.

### Ports

**INPUTS**

* stage_stall_i: stall
* icache_miss_i: cache miss (generated by not valid or tag miss)
* is_branch_i: the instruction currently in IWS stage is a branch 
* branch_address_i: branch address
* branch_outcome_i: branch resolution from EXECUTE stage
* ibuffer_supply_i: instruction buffer needs instructions
* increment_pc_i: from IWS stage

**OUTPUTS**

* cache_read_o: read cache
* axi_read_o: read axi
* instr_address_o: address cache and axi
* cache_block_ready_o: cache block can be read
* flush_decode_o: flush decode stage 
* stall_itag_o: stall instruction tag stage (don't deliver any valid instruction)
* jump_mispredict_o: change instruction register
* misaligned_access_o: misaligned memory access


## Instruction Word Supply

### General behaviour

The IWS is the second stage of accessing the cache, the block read in the preceeding stage is now delivered by memory, here tag get checked if an hit occours then the execution flow continues normally otherwise it will command the AXI to fetch the current address missed. During a miss the first two stages are stalled, AXI interface supplied of the current address and a read signal, after a while two data words arrives and the stage decide which words are valid based on PC (IWS value) value (if PC[3:2] is 10 for example then 3th and 4th words of the block can be fetched). Also it is the very first decode stage, here the instruction is partially decoded to check if it's compressed or not and if it's a branch or not. If it's compressed then only 16 bit are passed to the actual decoder and a bit (compressed) is also passed.

The instruction are memorized into a shift register, the last stage is directly connected with DECODE stage. This buffer memorize instructions that are sequentials, if a jump occour and another block of instructions get accessed, the buffer is switched with another and the new instructions loaded there. If the prediction was wrong the buffer get reswitched.

If this stage is stalled a NOP instruction is passed to DECODE stage

If there is a branch IAS will try to predict the outcome, the next clock cycle the data should arrive but also the branch outcome. If the prediction was correct and there's an hit then write in ibuffer, otherwise don't load the buffer.



### Ports

**INPUTS**

* program_counter_i: PC value
* jump_mispredict_i
* stage_stall_i
* cache_block_ready_i
* cache_tag_i
* cache_block_valid_i
  
**OUTPUTS**

* instruction_o
* cache_miss_o
* increment_pc_o
* is_compressed_o
* is_branch_o


## Instruction Decode

### General behaviour

The DEC stage decode the instruction and generate a set of micro instructions, it also calculate the branch address and send it back to the IAS stage to make a prediction. This stage generate the illegal instruction exception.
Instructions are decoded in parallel in a decoder and a compressed decoder.

In parallel there's is also a dependency controller that tracks the busy units, the RAW dependencies and possible bypassing.

Bypass can happen in EXECUTE stage and DATA WORD SUPPLY stage

### Extension Decode

* I: ALL
* M: ALL
* F: ALL
* C: ALL
* D: ALL
* B: Zba, Zbb, Zbs


### Ports

**INPUTS**

* instruction_i
* stage_stall_i
* stage_flush_i
* data_foward_i
* busy_signals_i
* program_counter_i

**OUTPUTS**

* branch_target_address_o
* illegal_instruction_o
* destination_register_o
* source1_register_o
* source2_register_o
* source2_is_immediate_o
* operand_A_o
* operand_B_o
* operation_o


## Execution 

Contains ALU, Multiply and Divide unit, FPU and CSR

ALU: perform basic operations  they are all single cycle

**INTEGER** 

ADDI:  rd = rs1 + $sext(imm) (no overflow)

SLTI:  rd = $signed(rs1 < $sext(imm))
SLTIU: rd = $unsigned(rs1 < $sext(imm))

ANDI:  rd = rs1 & $sext(imm)
ORI:   rd = rs1 | $sext(imm)
XORI:  rd = rs1 ^ $sext(imm)

SLLI:  rd = rs1 << imm
SRLI:  rd = rs1 >> imm
SRLI:  rd = rs1 >>> imm

LUI:   rd = {imm, 0} + 0 
AUIPC: rd = {imm, 0} + instr_addr

ADD:   rd = rs1 + rs2 (no overflow)
SUB:   rd = rs1 - rs2 (no overflow)

SLT:   rd = $signed(rs1 < rs2)
SLTU:  rd = $unsigned(rs1 < rs2)  (rd = 0 <=> rs1 = x0 & rs1 = rs2)

AND:  rd = rs1 & rs2
OR:   rd = rs1 | rs2
XOR:  rd = rs1 ^ rs2

SLL:  rd = rs1 << rs2[4:0]
SRL:  rd = rs1 >> rs2[4:0]
SRL:  rd = rs1 >>> rs2[4:0]

NOP:  rd(x0) = rs1(x0) + 0

// Done in DECODE
JAL:  PC = {imm, 0} + instr_addr (For RAS operation see page 21 - 22)
      rd = PC + 4
JALR: PC = ({imm, 0} + rs1) <- set bit LSB to 0 (For RAS operation see page 21 - 22)
      rd = PC + 4

// Address calc is done in decode reg dest is x0
BEQ:  PC = (rs1 == rs2) ? $sext(imm) + instr_addr : PC + 4;
BNE:  PC = (rs1 != rs2) ? $sext(imm) + instr_addr : PC + 4;
BLT:  PC = (rs1 < rs2) ? $sext(imm) + instr_addr : PC + 4;
BLTU: PC = $unsigned(rs1 < rs2) ? $sext(imm) + instr_addr : PC + 4;
BGE:  PC = (rs1 > rs2) ? $sext(imm) + instr_addr : PC + 4;
BGEU: PC = $unsigned(rs1 > rs2) ? $sext(imm) + instr_addr : PC + 4;

LW:   rd = data[rs1 + $sext(imm)] <- Raise exeption if rd = x0
LH:   rd = $sext(data[rs1 + $sext(imm)][15:0100]) <- Raise exeption if rd = x0
LHU:  rd = data[rs1 + $sext(imm)][15:0] <- Raise exeption if rd = x0
LB:   rd = $sext(data[rs1 + $sext(imm)][7:0]) <- Raise exeption if rd = x0
LBU:  rd = data[rs1 + $sext(imm)][7:0] <- Raise exeption if rd = x0

SW:   data[rs1 + $sext(imm)] = rs2
SH:   data[rs1 + $sext(imm)] = rs2[15:0] 
SB:   data[rs1 + $sext(imm)] = rs2[7:0] 

FENCE: wait until write buffer is empty, the pipe is empty and current transactions are expired flush D$
FENCE.I: flush I$
ECALL: https://jborza.com/emulation/2021/04/22/ecalls-and-syscalls.html
EBREAK: Exception

CSRRW:  rd = CSR_old; 
        CSR = rs1
CSRRS:  rd = CSR | rs1; <- If rs1 = x0 instruction doesn't write
CSRRC:  rd = CSR & ~(rs1) <- If rs1 = x0 instruction doesn't write
CSRRWI: rd = CSR_old; 
        CSR = {0, imm}
CSRRSI: rd = CSR | {0, imm}; <- If imm = 0 instruction doesn't write
CSRRCI: rd = CSR & ~({0, imm}) <- If imm = 0 instruction doesn't write

RDCYCLE:    rd = cycle_counter[31:0]
RDTIME:     rd = time_counter[31:0]
RDINSTRET:  rd = instr_ret_counter[31:0]
RDCYCLEH:   rd = cycle_counter[64:32]
RDTIMEH:    rd = time_counter[64:32]
RDINSTRETH: rd = instr_ret_counter[64:32]


**FLOATING POINT and DOUBLE**

FLW:     rd = data[rs1 + $sext(imm)]
FSW:     data[rs1 + $sext(imm)] = rs2
FADD.S:  rd = rs1 + rs2
FSUB.S:  rd = rs1 - rs2
FMUL.S:  rd = rs1 * rs2
FDIV.S:  rd = rs1 / rs2
FSQRT.S: rd = sqrt(rs1)
FMIN.S:  rd = min(rs1, rs2)
FMAX.S:  rd = max(rs1, rs2)
FMADD.S  rd = (rs1 * rs2) + rs3
FMSUB.S  rd = (rs1 * rs2) - rs3
FNMSUB.S rd = -(rs1 * rs2) + rs3
FNMADD.S rd = -(rs1 * rs2) - rs3
FCVT.W.S rd = $signed((int)(rs1))      <- rs1 is float, rd is float
FCVT.WU.S rd = $unsigned((int)(rs1))   <- rs1 is float, rd is float
FCVT.S.W  rd = $signed((float)(rs1))   <- rs1 is int, rd is float
FCVT.S.WU rd = $unsigned((float)(rs1)) <- rs1 is int, rd is float
FSGNJ.s   rd = {rs2[Sign], rs1[Exp, Mantissa]}
FSGNJN.s  rd = {!rs2[Sign], rs1[Exp, Mantissa]}
FSGNJX.s  rd = {rs2[Sign] ^ rs1[Sign], rs1[Exp, Mantissa]}
FMV.X.W   rd(int) <- rs1(float)
FMV.W.X   rd(float) <- rs1(int)
FLT.S     rd = (rs1 < rs2)
FLE.S     rd = (rs1 <= rs2)
FEQ.S     rd = (rs1 == rs2)
FCLASS This instruction examines the value in floating-point register rs1 and
       writes to integer register rd a 10-bit mask that indicates the class of the floating-point
       number


**MULTIPLICATION**
MUL:    rd = $signed(rs1 * rs2)[31:0]
MULH:   rd = $signed(rs1 * rs2)[63:32]
MULHU:  rd = $unsigned(rs1 * rs2)[63:32]
MULHSU: rd = $signed(rs1) * $unsigned(rs2)[63:32]
DIV:    rd = $signed(rs1 / rs2)
DIVU:   rd = $unsigned(rs1 / rs2)
REM:    rd = $signed(rs1 % rs2)
REMU:   rd = $unsigned(rs1 % rs2)


**BITMANIP**

*ZBA*

SH1ADD rd = rs2 + (rs1 << 1)
SH2ADD rd = rs2 + (rs1 << 2)
SH3ADD rd = rs2 + (rs1 << 3)
ANDN   rd = rs1 & ~rs2
ORN    rd = rs1 | ~rs2
XNOR   rd = ~(rs1 ^ rs2)
CLZ
CTZ
CPOP
MAX    rd = $signed(rs1 < rs2) ? rs2 : rs1
MAXU   rd = $unsigned(rs1 < rs2) ? rs2 : rs1
MIN    rd = $signed(rs1 < rs2) ? rs1 : rs2
MINU   rd = $unsigned(rs1 < rs2) ? rs1 : rs2
SEXT.B rd = {24rs1[7], rs1[7:0]}
SEXT.H rd = {24rs1[15], rs1[15:0]}
ZEXT.H rd = {24'b0, rs1[15:0]}
ROL    rd = (rs1 << rs2[4:0]) | (rs1 >> (32 - rs2[4:0]))
ROR    rd = (rs1 >> rs2[4:0]) | (rs1 << (32 - rs2[4:0]))
RORI   rd = (rs1 >> imm) | (rs1 << (32 - imm))
ORC.B  rd.bytex = |rs.bytex ? 0xFF : 0x00;
REV8   rd = rs reversed (byte)
BCLR   rd = rs1 & ~(1 << rs2[4:0]) <- 32 > rs2 >= 0
BCLRI  rd = rs1 & ~(1 << imm)
BEXT   rd = (rs1 >> rs2[4:0]) & 1
BEXTI  rd = (rs1 >> imm) & 1
BINV   rd = rs1 ^ (1 << rs2)
BINVI  rd = rs1 ^ (1 << imm)
BSET   rd = rs1 | (1 << rs2)
BSETI  rd = rs1 | (1 << imm)