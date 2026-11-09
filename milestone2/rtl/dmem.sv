module dmem #(
    parameter logic [31:0] START_ADDR = 32'h8008_0000,
    parameter int unsigned ADDR_WIDTH = 16
) (
    input  logic        i_clk   ,
    input  logic [31:0] i_addr  ,
    input  logic [31:0] i_wdata ,
    input  logic [ 3:0] i_bmsk  ,
    input  logic        i_wren  ,
    output logic [31:0] o_rdata
);

// Insert your code here.

    // ------------------------------------------------------------------
    // Byte-addressed, little-endian. Doc bat dong bo, ghi dong bo theo byte mask.
    // Luu theo word 32 bit: lane k = i_wdata[8k+7:8k] o dia chi (word + k).
    //
    // START_ADDR can theo kich thuoc vung (0x8008_0000 / 0x8400_0000 voi 16 bit),
    // nen dia chi hop le khi cac bit cao bang START_ADDR (chi dung '=='), va
    // chi so word = i_addr[ADDR_WIDTH-1:2]. Khong co phep tru hay so sanh thu tu.
    //
    // Ghi ngoai vung (vi du vao Testbench Memory Map) bi bo qua; doc ngoai vung tra 0.
    // ------------------------------------------------------------------
    logic [31:0]           dmem [2**(ADDR_WIDTH-2)];
    logic [ADDR_WIDTH-1:2] word_addr;
    logic                  in_range;

    // Khoi tao 0 de lenh load vao vung chua ghi khong ra X (model memory: TA cho
    // phep dung toan tu/vong lap binh thuong o day, chi rang buoc phan core logic)
    initial begin
        for (int i = 0; i < 2**(ADDR_WIDTH-2); i++) dmem[i] = 32'h0000_0000;
    end

    assign word_addr = i_addr[ADDR_WIDTH-1:2];
    assign in_range  = (i_addr[31:ADDR_WIDTH] == START_ADDR[31:ADDR_WIDTH]);

    always_ff @(posedge i_clk) begin
        if (i_wren && in_range) begin
            if (i_bmsk[0]) dmem[word_addr][ 7: 0] <= i_wdata[ 7: 0];
            if (i_bmsk[1]) dmem[word_addr][15: 8] <= i_wdata[15: 8];
            if (i_bmsk[2]) dmem[word_addr][23:16] <= i_wdata[23:16];
            if (i_bmsk[3]) dmem[word_addr][31:24] <= i_wdata[31:24];
        end
    end

    assign o_rdata = in_range ? dmem[word_addr] : 32'h0000_0000;

endmodule
