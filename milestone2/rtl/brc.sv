// Branch Comparison Unit (muc 4.2, cong theo Table 2).
// Dung lai comparator cua milestone 1 (prefix AND, khong co toan tu so sanh).
module brc (
    input  logic [31:0] i_rs1_data,
    input  logic [31:0] i_rs2_data,
    input  logic        i_br_unsigned,  // 1: khong dau, 0: co dau
    output logic        o_br_equal,
    output logic        o_br_less
);
    logic unused_gt;

    comparator u_cmp (
        .i_a        (i_rs1_data),
        .i_b        (i_rs2_data),
        .i_unsigned (i_br_unsigned),
        .o_eq       (o_br_equal),
        .o_lt       (o_br_less),
        .o_gt       (unused_gt)
    );
endmodule
