module control_unit (
	input  logic [31:0]	i_inst,			// lenh 32 bit tu Instruction Memory
	input  logic        	i_br_less,  	// ket qua so sanh tu BRC	// nho hon
	input  logic       	i_br_equal,    									// bang
	output logic [3:0]  	o_alu_op,    	// chon phep toan ALU (ma {funct7[5], funct3})
	output logic       	o_reg_wen,		// cho phep ghi vao register file
	output logic       	o_alu_a_sel,	// 0: rs1; 1: pc
	output logic       	o_alu_b_sel,	// 0: rs2; 1: IMM
	output logic [2:0] 	o_immsel,		// chon immediate I S J B U
	output logic [1:0] 	o_wb_sel,		// 00: LSU, 01: ALU, 10: PC+4, 11: IMM (LUI)
	output logic       	o_dmem_we,		// cho phep ghi Data Memory (STORE)
	output logic       	o_br_un,			// 1: so sanh co dau, 0: khong dau
	output logic       	o_pc_sel,		// 0: PC+4, 1: nhay (ALU)
	output logic       	o_insn_vld,		// Instruction hop le ?
	output logic [2:0] 	o_lsu_type		// loai load/store = funct3 (000 B, 001 H, 010 W, 100 BU, 101 HU)
);
 // ===== OPCODES ===== //
	localparam logic [6:0] OP_LOAD   = 7'b0000011; // LB, LH, LW, LBU, LHU
	localparam logic [6:0] OP_STORE  = 7'b0100011; // SB, SH, SW
	localparam logic [6:0] OP_BRANCH = 7'b1100011; // BEQ, BNE, BLT, BGE, BLTU, BGEU
	localparam logic [6:0] OP_JALR   = 7'b1100111;
	localparam logic [6:0] OP_JAL    = 7'b1101111;
	localparam logic [6:0] OP_OP_IMM = 7'b0010011; // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
	localparam logic [6:0] OP_OP     = 7'b0110011; // R-type
	localparam logic [6:0] OP_LUI    = 7'b0110111;
	localparam logic [6:0] OP_AUIPC  = 7'b0010111;

// ===== ALU OPERATIONS (khop alu.sv: {funct7[5], funct3}) ===== //
	localparam logic [3:0] ALU_ADD = 4'b0000;
	localparam logic [3:0] ALU_SLL = 4'b0001;
	localparam logic [3:0] ALU_SRL = 4'b0101;
	localparam logic [3:0] ALU_SRA = 4'b1101;

// ===== IMMEDIATE TYPES (khop imm_gen) ===== //
	localparam logic [2:0] IMM_I = 3'b000;
	localparam logic [2:0] IMM_S = 3'b001;
	localparam logic [2:0] IMM_B = 3'b010;
	localparam logic [2:0] IMM_U = 3'b011;
	localparam logic [2:0] IMM_J = 3'b100;

// ===== WRITE-BACK SELECT ===== //
	localparam logic [1:0] WB_LSU = 2'b00;
	localparam logic [1:0] WB_ALU = 2'b01;
	localparam logic [1:0] WB_PC4 = 2'b10;
	localparam logic [1:0] WB_IMM = 2'b11;

// ===== FUNCT3 ===== //
	localparam logic [2:0] F3_ADD_SUB = 3'b000;
	localparam logic [2:0] F3_SLL     = 3'b001;
	localparam logic [2:0] F3_SRL_SRA = 3'b101;

	localparam logic [2:0] F3_LB_SB = 3'b000;
	localparam logic [2:0] F3_LH_SH = 3'b001;
	localparam logic [2:0] F3_LW_SW = 3'b010;
	localparam logic [2:0] F3_LBU   = 3'b100;
	localparam logic [2:0] F3_LHU   = 3'b101;

	localparam logic [2:0] F3_BEQ  = 3'b000;
	localparam logic [2:0] F3_BNE  = 3'b001;
	localparam logic [2:0] F3_BLT  = 3'b100;
	localparam logic [2:0] F3_BGE  = 3'b101;
	localparam logic [2:0] F3_BLTU = 3'b110;
	localparam logic [2:0] F3_BGEU = 3'b111;

// ===== FUNCT7 ===== //
	localparam logic [6:0] F7_ZERO = 7'b0000000;
	localparam logic [6:0] F7_ALT  = 7'b0100000;	// SUB, SRA, SRAI

// ===== LSU TYPE (khop lsu.sv): chinh la funct3 ===== //
	localparam logic [2:0] LSU_B  = 3'b000;
	localparam logic [2:0] LSU_H  = 3'b001;
	localparam logic [2:0] LSU_W  = 3'b010;
	localparam logic [2:0] LSU_BU = 3'b100;
	localparam logic [2:0] LSU_HU = 3'b101;

// ===== tach instruction ===== //
	logic [6:0] opcode;
	logic [2:0] funct3;
	logic [6:0] funct7;
	logic       pc_sel_branch;		// 1: dieu kien branch dung
	logic       vld;					// lenh hop le (chua gate)
	logic       reg_wen, dmem_we, pc_sel;

	assign opcode = i_inst[6:0];
	assign funct3 = i_inst[14:12];
	assign funct7 = i_inst[31:25];

// ===== dieu kien nhay cua branch ===== //
	always_comb begin
		case (funct3)
			F3_BEQ  : pc_sel_branch =  i_br_equal;
			F3_BNE  : pc_sel_branch = ~i_br_equal;
			F3_BLT  : pc_sel_branch =  i_br_less;
			F3_BGE  : pc_sel_branch = ~i_br_less;	// >= tuc la khong nho hon
			F3_BLTU : pc_sel_branch =  i_br_less;
			F3_BGEU : pc_sel_branch = ~i_br_less;
			default : pc_sel_branch = 1'b0;
		endcase
	end

					// =========== CONTROL UNIT ========== //
	always_comb begin
		// gia tri mac dinh -> tranh latch
		o_alu_op    = ALU_ADD;
		reg_wen     = 1'b0;
		o_alu_a_sel = 1'b0;
		o_alu_b_sel = 1'b0;
		o_immsel    = IMM_I;
		o_wb_sel    = WB_ALU;
		dmem_we     = 1'b0;
		o_br_un     = 1'b0;
		pc_sel      = 1'b0;
		vld         = 1'b0;
		o_lsu_type  = LSU_W;

		case (opcode)
			// === R-type === //
			// ma ALU = {funct7[5], funct3}; chi chap nhan funct7 = 0000000,
			// hoac 0100000 voi ADD/SUB va SRL/SRA (MUL/DIV... -> khong hop le)
			OP_OP : begin
				reg_wen  = 1'b1;
				o_wb_sel = WB_ALU;
				o_alu_op = {funct7[5], funct3};
				vld      = (funct7 == F7_ZERO) ||
				           ((funct7 == F7_ALT) && ((funct3 == F3_ADD_SUB) || (funct3 == F3_SRL_SRA)));
			end

			// === I-type ALU === //
			OP_OP_IMM : begin
				reg_wen     = 1'b1;
				o_alu_b_sel = 1'b1;
				o_immsel    = IMM_I;
				o_wb_sel    = WB_ALU;
				case (funct3)
					F3_SLL     : begin		// SLLI: imm[11:5] phai = 0
						o_alu_op = ALU_SLL;
						vld      = (funct7 == F7_ZERO);
					end
					F3_SRL_SRA : begin		// SRLI: 0000000, SRAI: 0100000
						o_alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
						vld      = (funct7 == F7_ZERO) || (funct7 == F7_ALT);
					end
					default    : begin		// ADDI, SLTI, SLTIU, XORI, ORI, ANDI: khong co SUBI
						o_alu_op = {1'b0, funct3};
						vld      = 1'b1;
					end
				endcase
			end

			// === LOAD === //
			OP_LOAD : begin
				reg_wen     = 1'b1;
				o_alu_b_sel = 1'b1;
				o_immsel    = IMM_I;
				o_wb_sel    = WB_LSU;
				o_alu_op    = ALU_ADD;
				vld         = 1'b1;
				case (funct3)
					F3_LW_SW : o_lsu_type = LSU_W;
					F3_LB_SB : o_lsu_type = LSU_B;
					F3_LBU   : o_lsu_type = LSU_BU;
					F3_LH_SH : o_lsu_type = LSU_H;
					F3_LHU   : o_lsu_type = LSU_HU;
					default  : vld        = 1'b0;
				endcase
			end

			// === STORE === //
			OP_STORE : begin
				dmem_we     = 1'b1;
				o_alu_b_sel = 1'b1;
				o_immsel    = IMM_S;
				o_alu_op    = ALU_ADD;
				vld         = 1'b1;
				case (funct3)
					F3_LW_SW : o_lsu_type = LSU_W;
					F3_LB_SB : o_lsu_type = LSU_B;
					F3_LH_SH : o_lsu_type = LSU_H;
					default  : vld        = 1'b0;
				endcase
			end

			// === BRANCH === //
			OP_BRANCH : begin
				o_alu_a_sel = 1'b1;		// PC
				o_alu_b_sel = 1'b1;		// IMM
				o_alu_op    = ALU_ADD;
				o_immsel    = IMM_B;
				pc_sel      = pc_sel_branch;
				case (funct3)
					F3_BEQ, F3_BNE, F3_BLT, F3_BGE : begin o_br_un = 1'b1; vld = 1'b1; end
					F3_BLTU, F3_BGEU               : begin o_br_un = 1'b0; vld = 1'b1; end
					default                        : vld = 1'b0;
				endcase
			end

			// === JAL === //
			OP_JAL : begin
				reg_wen     = 1'b1;
				o_alu_a_sel = 1'b1;
				o_alu_b_sel = 1'b1;
				o_immsel    = IMM_J;
				o_wb_sel    = WB_PC4;
				pc_sel      = 1'b1;
				o_alu_op    = ALU_ADD;
				vld         = 1'b1;
			end

			// === JALR === //
			OP_JALR : begin
				reg_wen     = 1'b1;
				o_alu_b_sel = 1'b1;
				o_immsel    = IMM_I;
				o_wb_sel    = WB_PC4;
				pc_sel      = 1'b1;
				o_alu_op    = ALU_ADD;
				vld         = (funct3 == 3'b000);
			end

			// === LUI: rd = imm (khong qua ALU, vi bit [19:15] la imm chu khong phai rs1) === //
			OP_LUI : begin
				reg_wen  = 1'b1;
				o_immsel = IMM_U;
				o_wb_sel = WB_IMM;
				vld      = 1'b1;
			end

			// === AUIPC === //
			OP_AUIPC : begin
				reg_wen     = 1'b1;
				o_alu_a_sel = 1'b1;
				o_alu_b_sel = 1'b1;
				o_immsel    = IMM_U;
				o_alu_op    = ALU_ADD;
				o_wb_sel    = WB_ALU;
				vld         = 1'b1;
			end

			default : vld = 1'b0;
		endcase
	end

	// Lenh khong hop le: khong ghi regfile, khong ghi memory, khong nhay (chay nhu NOP)
	assign o_insn_vld = vld;
	assign o_reg_wen  = reg_wen & vld;
	assign o_dmem_we  = dmem_we & vld;
	assign o_pc_sel   = pc_sel  & vld;

endmodule
