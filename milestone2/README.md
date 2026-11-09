# Milestone 2 – Single-cycle RV32I processor

Single-cycle RISC-V processor (RV32I, 37 instructions) written in SystemVerilog for the
Computer Architecture Laboratory course at HCMUT. Every instruction completes in one clock
cycle (IPC = 1).

## Modules (`rtl/`)

| File | Module | Role |
|---|---|---|
| `singlecycle.sv` | `singlecycle` | Top level: PC register, next-PC mux, ALU operand muxes, write-back mux, `o_db_valid` |
| `control.sv` | `control_unit` | Decodes opcode/funct3/funct7, checks legality, branch decision, all control signals |
| `regfile.sv` | `regfile` | 32 × 32-bit, 2 asynchronous read ports, 1 synchronous write port, x0 = 0 |
| `imm_gen.sv` | `imm_gen` | Sign-extended immediate for I/S/B/U/J formats |
| `brc.sv` | `brc` | Branch comparison (signed / unsigned) → `br_equal`, `br_less` |
| `alu.sv` | `alu` | ADD/SUB, SLT/SLTU, shifts, XOR/OR/AND |
| `adder.sv` | `adder` | 32-bit Kogge-Stone adder |
| `add_sub.sv` | `add_sub` | Adder wrapper used for PC + 4 |
| `comparator.sv` | `comparator` | Prefix-AND magnitude comparator |
| `shifter.sv` | `shifter` | 5-stage barrel shifter (SLL/SRL/SRA) |
| `lsu.sv` | `lsu` | Byte mask, store-lane alignment, load sign/zero extension |
| `imem.sv` | `imem` | Instruction memory (course template, `$readmemh`, async read) |
| `dmem.sv` | `dmem` | Data memory (course template, async read, byte-masked sync write) |

The core logic uses no `+ - < > <= >= << >> >>> * / %` operators and no `function`/`task`,
as required by the course: arithmetic goes through the hand-written adder, comparator and shifter.

The top-level wrapper `milestone2.sv`, the testbench and the test programs belong to the
course and are not included in this repository.

## Results (course testbench, Cadence Xcelium)

| Test | Result | Cycles | Instructions | IPC |
|---|---|---|---|---|
| ISA_TEST | 37/37 tests, 86/86 check groups, 404,988/404,988 cases, score 6.00/6.00 | 5,497,867 | 5,497,867 | 1.0000 |
| PROG_HANOI | PASS | 339,657 | 339,657 | 1.0000 |
| PROG_SORT | PASS | 486,758 | 486,758 | 1.0000 |
| PROG_MATRIX | PASS | 171,393 | 171,393 | 1.0000 |
| PROG_SOFTFLOAT | PASS | 2,857,414 | 2,857,414 | 1.0000 |
| PROG_SIGMOID | PASS | 3,822,619 | 3,822,619 | 1.0000 |
| PROG_CONVOLUTION | PASS | 1,811,378 | 1,811,378 | 1.0000 |

## Local test (`local_test/`)

A stand-alone check with Icarus Verilog: `gen_test.py` assembles a random RV32I program and
computes the expected trace (golden model), `milestone2_mock.sv` replaces the course wrapper,
and `tb_milestone2_local.sv` compares PC, `o_db_valid`, register writes and memory every cycle.
Run `local_test/run.sh` from the `milestone2/` folder.

## Known limitations

- Misaligned loads/stores that cross a 32-bit word boundary are not supported (no trap).
- FENCE, ECALL, EBREAK and non-RV32I encodings execute as a NOP with `o_db_valid` = 0.
