// Immediate Generator (muc 4.3, cong theo Table 4).
// i_imm_sel: 000 I, 001 S, 010 B, 011 U, 100 J
module imm_gen (
    input  logic [31:0] i_instr,
    input  logic [2:0]  i_imm_sel,
    output logic [31:0] o_imm
);
    localparam logic [2:0] I_TYPE = 3'b000;
    localparam logic [2:0] S_TYPE = 3'b001;
    localparam logic [2:0] B_TYPE = 3'b010;
    localparam logic [2:0] U_TYPE = 3'b011;
    localparam logic [2:0] J_TYPE = 3'b100;

    always_comb begin
        case (i_imm_sel)
            I_TYPE:  o_imm = {{20{i_instr[31]}}, i_instr[31:20]};
            S_TYPE:  o_imm = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
            B_TYPE:  o_imm = {{19{i_instr[31]}}, i_instr[31], i_instr[7],
                              i_instr[30:25], i_instr[11:8], 1'b0};
            U_TYPE:  o_imm = {i_instr[31:12], 12'b0};
            J_TYPE:  o_imm = {{11{i_instr[31]}}, i_instr[31], i_instr[19:12],
                              i_instr[20], i_instr[30:21], 1'b0};
            default: o_imm = 32'd0;
        endcase
    end
endmodule
