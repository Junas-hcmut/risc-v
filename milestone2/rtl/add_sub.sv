			// ===== ADDER 32 BITS ===== //
// Giu nguyen cong cua ban goc: s = x + y + c_in, c_out = carry ra khoi bit 31.
// Ben trong dung adder Kogge-Stone cua milestone 1 thay cho chuoi 32 full_adder.
//
// adder tinh a + (b ^ {32{i_sub}}) + i_sub. Cho i_b = y ^ {32{c_in}} va i_sub = c_in
// thi b_eff = y, carry-in = c_in -> dung x + y + c_in.
// O che do khong dau, adder dinh nghia o_cout = carry khi cong va = borrow (= ~carry)
// khi tru, nen carry that = o_cout ^ c_in.
module add_sub (
	input  logic [31:0] x, y,
	input  logic        c_in,
	output logic [31:0] s,
	output logic        c_out
);
	logic cout_adder;

	adder u_adder (
		.i_a        (x),
		.i_b        (y ^ {32{c_in}}),
		.i_sub      (c_in),
		.i_unsigned (1'b1),
		.o_sum      (s),
		.o_cout     (cout_adder)
	);

	assign c_out = cout_adder ^ c_in;
endmodule
