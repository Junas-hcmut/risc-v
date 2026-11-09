// Exercise 4: Arithmetic Logic Unit.
//
// The adder, comparator and shifter of exercises 1 to 3 are each instantiated
// once and shared:
//   adder      : ADD, SUB
//   comparator : SLT, SLTU
//   shifter    : SLL, SRL, SRA
// The bitwise operations are implemented here. A final multiplexer selects the
// result; unused encodings of i_alu_op drive zero.

module alu (
  input  logic [31:0] i_op_a,
  input  logic [31:0] i_op_b,
  input  logic [3:0]  i_alu_op,
  output logic [31:0] o_alu_data
);

  // ALU operation encoding = {funct7[5], funct3} cua lenh R-type RV32I
  localparam logic [3:0] ALU_ADD  = 4'b0000;
  localparam logic [3:0] ALU_SLL  = 4'b0001;
  localparam logic [3:0] ALU_SLT  = 4'b0010;
  localparam logic [3:0] ALU_SLTU = 4'b0011;
  localparam logic [3:0] ALU_XOR  = 4'b0100;
  localparam logic [3:0] ALU_SRL  = 4'b0101;
  localparam logic [3:0] ALU_OR   = 4'b0110;
  localparam logic [3:0] ALU_AND  = 4'b0111;
  localparam logic [3:0] ALU_SUB  = 4'b1000;
  localparam logic [3:0] ALU_SRA  = 4'b1101;

  // Shifter mode encoding (Table 4 of the specification)
  localparam logic [1:0] SHIFT_SRL = 2'b00;
  localparam logic [1:0] SHIFT_SLL = 2'b01;
  localparam logic [1:0] SHIFT_SRA = 2'b10;

  // Value driven on o_alu_data for unused encodings
  localparam logic [31:0] SAFE_VALUE = 32'h0000_0000;

  logic        adder_sub;
  logic [31:0] adder_sum;
  logic        unused_adder_cout;

  logic        cmp_unsigned;
  logic        cmp_lt;
  logic        unused_cmp_eq;
  logic        unused_cmp_gt;

  logic [1:0]  shift_mode;
  logic [31:0] shift_data;

  // ------------------------------------------------------------------
  // Control of the shared blocks
  // ------------------------------------------------------------------
  assign adder_sub    = (i_alu_op == ALU_SUB);
  assign cmp_unsigned = (i_alu_op == ALU_SLTU);

  always_comb begin
    unique case (i_alu_op)
      ALU_SLL: shift_mode = SHIFT_SLL;
      ALU_SRA: shift_mode = SHIFT_SRA;
      default: shift_mode = SHIFT_SRL;
    endcase
  end

  // ------------------------------------------------------------------
  // Shared blocks
  // ------------------------------------------------------------------
  adder u_adder (
    .i_a        (i_op_a),
    .i_b        (i_op_b),
    .i_sub      (adder_sub),
    .i_unsigned (1'b0),               // only affects o_cout, which the ALU does not use
    .o_sum      (adder_sum),
    .o_cout     (unused_adder_cout)
  );

  comparator u_comparator (
    .i_a        (i_op_a),
    .i_b        (i_op_b),
    .i_unsigned (cmp_unsigned),
    .o_eq       (unused_cmp_eq),
    .o_lt       (cmp_lt),
    .o_gt       (unused_cmp_gt)
  );

  shifter u_shifter (
    .i_data  (i_op_a),
    .i_shamt (i_op_b[4:0]),
    .i_mode  (shift_mode),
    .o_data  (shift_data)
  );

  // ------------------------------------------------------------------
  // Result selection
  // ------------------------------------------------------------------
  always_comb begin
    unique case (i_alu_op)
      ALU_ADD,
      ALU_SUB:  o_alu_data = adder_sum;
      ALU_SLT,
      ALU_SLTU: o_alu_data = {31'b0, cmp_lt};
      ALU_XOR:  o_alu_data = i_op_a ^ i_op_b;
      ALU_OR:   o_alu_data = i_op_a | i_op_b;
      ALU_AND:  o_alu_data = i_op_a & i_op_b;
      ALU_SLL,
      ALU_SRL,
      ALU_SRA:  o_alu_data = shift_data;
      default:  o_alu_data = SAFE_VALUE;
    endcase
  end

endmodule
