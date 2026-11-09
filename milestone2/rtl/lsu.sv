// Load/Store Unit (muc 4.6).
// Cong ra theo Table 8; cong vao do sinh vien tu thiet ke:
//   i_addr       : dia chi hieu dung (ket qua ALU = rs1 + imm)
//   i_st_data    : du lieu rs2 cho lenh store
//   i_type       : funct3 cua lenh load/store
//                  000 B, 001 H, 010 W, 100 BU, 101 HU
//   i_wren       : 1 voi lenh store (tu controller)
//   i_dmem_rdata : word doc tu DMEM
//
// DMEM truy cap theo word co byte mask, nen moi lenh chi cham 1 word. Truy cap
// lech nhung nam gon trong 1 word (vi du LH/SH o offset 1) van dung; truy cap vat
// sang word ke tiep (LW/SW lech, LH/SH o offset 3) chi lay phan nam trong word nay.
// Chi dung noi day va mux, khong dung toan tu dich hay so hoc.
module lsu (
    input  logic [31:0] i_addr,
    input  logic [31:0] i_st_data,
    input  logic [2:0]  i_type,
    input  logic        i_wren,
    input  logic [31:0] i_dmem_rdata,
    output logic [31:0] o_ld_data,
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wdata,
    output logic [ 3:0] o_dmem_bmsk,
    output logic        o_dmem_wren
);
    localparam logic [2:0] T_B  = 3'b000;
    localparam logic [2:0] T_H  = 3'b001;
    localparam logic [2:0] T_W  = 3'b010;
    localparam logic [2:0] T_BU = 3'b100;
    localparam logic [2:0] T_HU = 3'b101;

    logic [1:0]  offset;        // byte trong word
    logic [7:0]  ld_byte;
    logic [15:0] ld_half;

    assign offset      = i_addr[1:0];
    assign o_dmem_addr = i_addr;
    assign o_dmem_wren = i_wren;

    // ------------------------------------------------------------------
    // Store: dat byte/halfword vao dung lane va bat byte mask tuong ung.
    // Du lieu duoc nhan ban len moi lane, byte mask chon lane duoc ghi.
    // (Voi load, byte mask chi bao cac byte duoc doc; DMEM khong ghi vi wren = 0.)
    // ------------------------------------------------------------------
    always_comb begin
        case (i_type[1:0])
            2'b00: begin                                    // byte
                o_dmem_wdata = {4{i_st_data[7:0]}};
                case (offset)
                    2'b00: o_dmem_bmsk = 4'b0001;
                    2'b01: o_dmem_bmsk = 4'b0010;
                    2'b10: o_dmem_bmsk = 4'b0100;
                    2'b11: o_dmem_bmsk = 4'b1000;
                endcase
            end
            2'b01: begin                                    // halfword
                case (offset)
                    2'b00: begin
                        o_dmem_wdata = {2{i_st_data[15:0]}};
                        o_dmem_bmsk  = 4'b0011;
                    end
                    2'b01: begin
                        o_dmem_wdata = {8'b0, i_st_data[15:0], 8'b0};
                        o_dmem_bmsk  = 4'b0110;
                    end
                    2'b10: begin
                        o_dmem_wdata = {2{i_st_data[15:0]}};
                        o_dmem_bmsk  = 4'b1100;
                    end
                    2'b11: begin                            // vat sang word sau
                        o_dmem_wdata = {i_st_data[7:0], 24'b0};
                        o_dmem_bmsk  = 4'b1000;
                    end
                endcase
            end
            default: begin                                  // word
                case (offset)
                    2'b00: begin
                        o_dmem_wdata = i_st_data;
                        o_dmem_bmsk  = 4'b1111;
                    end
                    2'b01: begin
                        o_dmem_wdata = {i_st_data[23:0], 8'b0};
                        o_dmem_bmsk  = 4'b1110;
                    end
                    2'b10: begin
                        o_dmem_wdata = {i_st_data[15:0], 16'b0};
                        o_dmem_bmsk  = 4'b1100;
                    end
                    2'b11: begin
                        o_dmem_wdata = {i_st_data[7:0], 24'b0};
                        o_dmem_bmsk  = 4'b1000;
                    end
                endcase
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Load: chon byte/halfword theo offset, roi sign- hoac zero-extend
    // ------------------------------------------------------------------
    always_comb begin
        case (offset)
            2'b00: ld_byte = i_dmem_rdata[ 7: 0];
            2'b01: ld_byte = i_dmem_rdata[15: 8];
            2'b10: ld_byte = i_dmem_rdata[23:16];
            2'b11: ld_byte = i_dmem_rdata[31:24];
        endcase
        case (offset)
            2'b00: ld_half = i_dmem_rdata[15: 0];
            2'b01: ld_half = i_dmem_rdata[23: 8];
            2'b10: ld_half = i_dmem_rdata[31:16];
            2'b11: ld_half = {8'b0, i_dmem_rdata[31:24]};   // vat sang word sau
        endcase
    end

    always_comb begin
        case (i_type)
            T_B:     o_ld_data = {{24{ld_byte[7]}},  ld_byte};
            T_BU:    o_ld_data = {24'b0,             ld_byte};
            T_H:     o_ld_data = {{16{ld_half[15]}}, ld_half};
            T_HU:    o_ld_data = {16'b0,             ld_half};
            T_W:     begin
                case (offset)
                    2'b00: o_ld_data = i_dmem_rdata;
                    2'b01: o_ld_data = {8'b0,  i_dmem_rdata[31:8]};
                    2'b10: o_ld_data = {16'b0, i_dmem_rdata[31:16]};
                    2'b11: o_ld_data = {24'b0, i_dmem_rdata[31:24]};
                endcase
            end
            default: o_ld_data = i_dmem_rdata;
        endcase
    end

endmodule
