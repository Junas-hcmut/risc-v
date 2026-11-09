// Register File (Exercise 5, milestone 1): 32 thanh ghi, 2 cong doc bat dong bo,
// 1 cong ghi dong bo.
//   - x0 khong co phan tu nho: ghi vao dia chi 0 bi bo qua, doc dia chi 0 tra 0.
//   - i_rstn: reset bat dong bo tich cuc thap, xoa x1..x31.
//   - Doc thuan to hop, khong bypass tu cong ghi.
// Khai bao x1..x31 la mang packed de reset bang mot phep gan, khong can vong for
// (vong for co '<' va '++', thuoc nhom toan tu bi cam).
module regfile (
  input  logic        i_clk,
  input  logic        i_rstn,
  input  logic [4:0]  i_rs1_addr,
  input  logic [4:0]  i_rs2_addr,
  input  logic [4:0]  i_rd_addr,
  input  logic [31:0] i_rd_data,
  input  logic        i_rd_wren,
  output logic [31:0] o_rs1_data,
  output logic [31:0] o_rs2_data
);

  logic [31:1][31:0] reg_q;     // x1 .. x31
  logic              wr_en;

  assign wr_en = i_rd_wren && (i_rd_addr != 5'd0);

  always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      reg_q <= '0;
    end else if (wr_en) begin
      reg_q[i_rd_addr] <= i_rd_data;
    end
  end

  assign o_rs1_data = (i_rs1_addr == 5'd0) ? 32'd0 : reg_q[i_rs1_addr];
  assign o_rs2_data = (i_rs2_addr == 5'd0) ? 32'd0 : reg_q[i_rs2_addr];

endmodule
