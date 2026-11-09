// Wrapper GIA LAP de test cuc bo (KHONG nop). Mo phong cach milestone2.sv noi
// singlecycle voi imem/dmem theo Figure 4. File that cua TA giu nguyen.
// Ten file chuong trinh viet thang (Icarus khong truyen duoc parameter string qua 2 cap).
module milestone2_mock #(
    parameter logic [31:0] IMEM_START = 32'h8000_0000,
    parameter int unsigned IMEM_AW    = 19,
    parameter logic [31:0] DMEM_START = 32'h8008_0000,
    parameter int unsigned DMEM_AW    = 16) (
    input  logic        i_clk,
    input  logic        i_rstn,
    output logic        o_db_valid,
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wdata,
    output logic [ 3:0] o_dmem_bmsk,
    output logic        o_dmem_wren
);
    logic [31:0] core_imem_addr, imem_core_rdata, dmem_core_rdata;

    singlecycle u_core (
        .i_clk        (i_clk),
        .i_rstn       (i_rstn),
        .o_db_valid   (o_db_valid),
        .o_imem_addr  (core_imem_addr),
        .i_imem_rdata (imem_core_rdata),
        .o_dmem_addr  (o_dmem_addr),
        .o_dmem_wdata (o_dmem_wdata),
        .o_dmem_bmsk  (o_dmem_bmsk),
        .o_dmem_wren  (o_dmem_wren),
        .i_dmem_rdata (dmem_core_rdata)
    );

    imem #(.START_ADDR(IMEM_START), .ADDR_WIDTH(IMEM_AW), .PROGRAMFILE("prog_1b.hex")) u_imem (
        .i_clk  (i_clk),
        .i_addr (core_imem_addr),
        .o_data (imem_core_rdata)
    );

    dmem #(.START_ADDR(DMEM_START), .ADDR_WIDTH(DMEM_AW)) u_dmem (
        .i_clk   (i_clk),
        .i_addr  (o_dmem_addr),
        .i_wdata (o_dmem_wdata),
        .i_bmsk  (o_dmem_bmsk),
        .i_wren  (o_dmem_wren),
        .o_rdata (dmem_core_rdata)
    );
endmodule
