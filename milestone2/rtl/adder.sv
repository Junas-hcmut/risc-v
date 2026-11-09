// Exercise 1: 32-bit adder/subtractor.
//
// Architecture: Kogge-Stone parallel-prefix adder. The carries are computed by a
// five-level prefix network (log2(32) levels) instead of rippling through 32 full
// adders. No arithmetic operator is used anywhere in this file.
//
// Subtraction uses two's complement: a minus b = a plus (not b) plus 1, so i_sub
// inverts the second operand and is also the carry into bit 0.
//
// Meaning of o_cout: {o_cout, o_sum} is the exact 33-bit result of the operation
// after both operands are extended to 33 bits (zero-extended when i_unsigned is
// high, sign-extended when it is low). Consequences:
//   unsigned add : o_cout = carry out of bit 31 (the sum does not fit in 32 bits)
//   unsigned sub : o_cout = borrow (i_a is below i_b)
//   signed       : o_cout = sign of the exact result; it differs from o_sum[31]
//                  exactly when the 32-bit signed result overflows
// o_sum itself does not depend on i_unsigned.

module adder (
  input  logic [31:0] i_a,
  input  logic [31:0] i_b,
  input  logic        i_sub,
  input  logic        i_unsigned,
  output logic [31:0] o_sum,
  output logic        o_cout
);

  logic [31:0] b_eff;       // second operand after the optional inversion
  logic        cin;         // carry into bit 0
  logic [31:0] p;           // bit propagate
  logic [31:0] g;           // bit generate

  // Group generate/propagate after each prefix level. After level k, bit i covers
  // the group [i : i-(2^k)+1] (clipped at bit 0).
  logic [31:0] g_l0, g_l1, g_l2, g_l3, g_l4, g_l5;
  logic [31:0] p_l0, p_l1, p_l2, p_l3, p_l4;

  logic [31:0] carry;       // carry into each bit position
  logic        carry_out;   // carry out of bit 31
  logic        a_ext;       // bit 32 of the extended first operand
  logic        b_ext;       // bit 32 of the extended (and inverted) second operand

  // ------------------------------------------------------------------
  // Operand conditioning
  // ------------------------------------------------------------------
  assign b_eff = i_b ^ {32{i_sub}};
  assign cin   = i_sub;

  // ------------------------------------------------------------------
  // Pre-processing: per-bit propagate and generate
  // ------------------------------------------------------------------
  assign p = i_a ^ b_eff;
  assign g = i_a & b_eff;

  // The carry-in is folded into the generate of bit 0, so every group that reaches
  // bit 0 already accounts for it.
  assign g_l0 = {g[31:1], g[0] | (p[0] & cin)};
  assign p_l0 = p;

  // ------------------------------------------------------------------
  // Prefix network. At a level with span d each bit i merges with bit i-d:
  //   G[i] = G[i] | (P[i] & G[i-d])
  //   P[i] = P[i] & P[i-d]
  // The partner vector is the previous level moved up by d positions. Positions
  // that have no partner receive the identity element (G = 0, P = 1), which
  // leaves them unchanged.
  // ------------------------------------------------------------------
  // Level 1, span 1
  assign g_l1 = g_l0 | (p_l0 & {g_l0[30:0], 1'b0});
  assign p_l1 = p_l0 & {p_l0[30:0], 1'b1};
  // Level 2, span 2
  assign g_l2 = g_l1 | (p_l1 & {g_l1[29:0], 2'b00});
  assign p_l2 = p_l1 & {p_l1[29:0], 2'b11};
  // Level 3, span 4
  assign g_l3 = g_l2 | (p_l2 & {g_l2[27:0], 4'h0});
  assign p_l3 = p_l2 & {p_l2[27:0], 4'hF};
  // Level 4, span 8
  assign g_l4 = g_l3 | (p_l3 & {g_l3[23:0], 8'h00});
  assign p_l4 = p_l3 & {p_l3[23:0], 8'hFF};
  // Level 5, span 16 (the group propagate is no longer needed)
  assign g_l5 = g_l4 | (p_l4 & {g_l4[15:0], 16'h0000});

  // ------------------------------------------------------------------
  // Post-processing: g_l5[i] is the carry out of bit i
  // ------------------------------------------------------------------
  assign carry     = {g_l5[30:0], cin};
  assign carry_out = g_l5[31];
  assign o_sum     = p ^ carry;

  // ------------------------------------------------------------------
  // Bit 32 of the extended result: one more sum bit on top of the 32-bit adder
  // ------------------------------------------------------------------
  assign a_ext  = ~i_unsigned & i_a[31];
  assign b_ext  = (~i_unsigned & i_b[31]) ^ i_sub;
  assign o_cout = a_ext ^ b_ext ^ carry_out;

endmodule
