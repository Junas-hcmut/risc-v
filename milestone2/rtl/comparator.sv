// Exercise 2: 32-bit magnitude comparator (signed and unsigned).
//
// Architecture: parallel-prefix comparator. i_a is below i_b when there is a bit
// position where i_a has 0 and i_b has 1 while all more significant bits are
// equal. "All more significant bits are equal" is a prefix AND starting from the
// MSB, computed in five doubling levels (log2(32)). No relational operator is
// used anywhere in this file.
//
// Signed comparison reuses the unsigned datapath: inverting the sign bit of both
// operands maps the two's complement range onto the unsigned range while keeping
// the ordering.

module comparator (
  input  logic [31:0] i_a,
  input  logic [31:0] i_b,
  input  logic        i_unsigned,
  output logic        o_eq,
  output logic        o_lt,
  output logic        o_gt
);

  logic [31:0] a;          // operands after the sign-bit adjustment
  logic [31:0] b;
  logic [31:0] bit_eq;     // bit i of both operands is equal
  logic [31:0] bit_lt;     // bit i is 0 in a and 1 in b

  // After level k, eq_lk[i] = AND of bit_eq[i +: 2^k] (clipped at bit 31).
  logic [31:0] eq_l1, eq_l2, eq_l3, eq_l4, eq_l5;
  logic [31:0] eq_above;   // all bits above position i are equal

  logic        eq;
  logic        lt;

  // ------------------------------------------------------------------
  // Sign handling
  // ------------------------------------------------------------------
  assign a = {i_a[31] ^ ~i_unsigned, i_a[30:0]};
  assign b = {i_b[31] ^ ~i_unsigned, i_b[30:0]};

  // ------------------------------------------------------------------
  // Per-bit comparison
  // ------------------------------------------------------------------
  assign bit_eq = ~(a ^ b);
  assign bit_lt = ~a & b;

  // ------------------------------------------------------------------
  // Prefix AND from the MSB down. Positions without a partner receive 1.
  // ------------------------------------------------------------------
  assign eq_l1 = bit_eq & {1'b1,     bit_eq[31:1]};
  assign eq_l2 = eq_l1  & {2'b11,    eq_l1[31:2]};
  assign eq_l3 = eq_l2  & {4'hF,     eq_l2[31:4]};
  assign eq_l4 = eq_l3  & {8'hFF,    eq_l3[31:8]};
  assign eq_l5 = eq_l4  & {16'hFFFF, eq_l4[31:16]};

  // eq_l5[i] covers bits [31:i], so the bits above position i are eq_l5[i+1].
  assign eq_above = {1'b1, eq_l5[31:1]};

  // ------------------------------------------------------------------
  // Results. At most one bit of (bit_lt & eq_above) can be set: the most
  // significant position where the operands differ.
  // ------------------------------------------------------------------
  assign eq = eq_l5[0];
  assign lt = |(bit_lt & eq_above);

  assign o_eq = eq;
  assign o_lt = lt;
  assign o_gt = ~(eq | lt);   // guarantees exactly one output is high

endmodule
