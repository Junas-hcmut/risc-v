module singlecycle (
    input  logic        i_clk        ,
    input  logic        i_rstn       ,
    output logic        o_db_valid   ,
    output logic [31:0] o_imem_addr  ,
    input  logic [31:0] i_imem_rdata ,
    output logic [31:0] o_dmem_addr  ,
    output logic [31:0] o_dmem_wdata ,
    output logic [ 3:0] o_dmem_bmsk  ,
    output logic        o_dmem_wren  ,
    input  logic [31:0] i_dmem_rdata
);

// Insert your code here.

    // PC reset = START_ADDR cua IMEM (giong nhau o ca 2 memory map trong Table 10)
    localparam logic [31:0] RESET_PC = 32'h8000_0000;

    logic [31:0] pc, pc_next, pc_four;
    logic [31:0] instr;
    logic [3:0]  o_alu_op;
    logic        o_alu_a_sel;
    logic        o_alu_b_sel;
    logic        o_reg_wen;
    logic [2:0]  o_immsel;
    logic [2:0]  o_lsu_type;
    logic [1:0]  o_wb_sel;
    logic        o_br_un;
    logic        o_dmem_we;
    logic        o_pc_sel;
    logic        o_insn_vld;
    logic        i_br_less;
    logic        i_br_equal;
    logic        cout_pc4;

// Register File signals
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] wb_data;

// Immediate value
    logic [31:0] imm;

// ALU signals
    logic [31:0] alu_op_a;
    logic [31:0] alu_op_b;
    logic [31:0] alu_data;

// LSU signals
    logic [31:0] ld_data;

// ===== Program Counter ===== //
    add_sub add_pc4 (
        .x    (pc),
        .y    (32'd4),
        .c_in (1'b0),
        .s    (pc_four),
        .c_out(cout_pc4)
    );

    // Khi nhay: lay ket qua ALU va xoa bit 0 (bat buoc voi JALR, vo hai voi JAL/branch)
    assign pc_next = o_pc_sel ? {alu_data[31:1], 1'b0} : pc_four;

    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) pc <= RESET_PC;
        else         pc <= pc_next;
    end

// ===== Instruction fetch ===== //
    assign o_imem_addr = pc;
    assign instr       = i_imem_rdata;

// ===== Controller ===== //
    control_unit ctrl (
        .i_inst     (instr),
        .i_br_less  (i_br_less),
        .i_br_equal (i_br_equal),
        .o_alu_op   (o_alu_op),
        .o_reg_wen  (o_reg_wen),
        .o_alu_a_sel(o_alu_a_sel),
        .o_alu_b_sel(o_alu_b_sel),
        .o_immsel   (o_immsel),
        .o_wb_sel   (o_wb_sel),
        .o_dmem_we  (o_dmem_we),
        .o_br_un    (o_br_un),
        .o_pc_sel   (o_pc_sel),
        .o_insn_vld (o_insn_vld),
        .o_lsu_type (o_lsu_type)
    );

    // Lenh hop le hoan thanh o canh len nay; giu muc thap khi dang reset
    assign o_db_valid = o_insn_vld & i_rstn;

// ===== Register File (Exercise 5, milestone 1) ===== //
    regfile regfile_inst (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .i_rs1_addr(instr[19:15]),
        .i_rs2_addr(instr[24:20]),
        .i_rd_addr (instr[11:7]),
        .i_rd_data (wb_data),
        .i_rd_wren (o_reg_wen),
        .o_rs1_data(rs1_data),
        .o_rs2_data(rs2_data)
    );

// ===== Immediate Generator ===== //
    imm_gen imm_gen_inst (
        .i_instr  (instr),
        .i_imm_sel(o_immsel),
        .o_imm    (imm)
    );

// ===== Branch Comparator ===== //
    brc brc_inst (
        .i_rs1_data   (rs1_data),
        .i_rs2_data   (rs2_data),
        .i_br_unsigned(~o_br_un),       // control: o_br_un = 1 la so sanh co dau
        .o_br_equal   (i_br_equal),
        .o_br_less    (i_br_less)
    );

// ===== ALU (Exercise 4, milestone 1) ===== //
    assign alu_op_a = o_alu_a_sel ? pc  : rs1_data;
    assign alu_op_b = o_alu_b_sel ? imm : rs2_data;

    alu alu_inst (
        .i_op_a    (alu_op_a),
        .i_op_b    (alu_op_b),
        .i_alu_op  (o_alu_op),
        .o_alu_data(alu_data)
    );

// ===== Load/Store Unit ===== //
    lsu lsu_inst (
        .i_addr      (alu_data),
        .i_st_data   (rs2_data),
        .i_type      (o_lsu_type),
        .i_wren      (o_dmem_we),
        .i_dmem_rdata(i_dmem_rdata),
        .o_ld_data   (ld_data),
        .o_dmem_addr (o_dmem_addr),
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_bmsk (o_dmem_bmsk),
        .o_dmem_wren (o_dmem_wren)
    );

// ===== Write-Back Mux ===== //
    always_comb begin
        case (o_wb_sel)
            2'b00:   wb_data = ld_data;     // LOAD
            2'b01:   wb_data = alu_data;    // ALU
            2'b10:   wb_data = pc_four;     // JAL / JALR
            2'b11:   wb_data = imm;         // LUI
            default: wb_data = 32'd0;
        endcase
    end

endmodule
