module imem #(
    parameter logic [31:0] START_ADDR  = 32'h8000_0000,
    parameter int unsigned ADDR_WIDTH  = 19,
    parameter string       PROGRAMFILE = ""
) (
    input  logic        i_clk  ,
    input  logic [31:0] i_addr ,
    output logic [31:0] o_data
);

// Insert your code here.

    // ------------------------------------------------------------------
    // Byte-addressed, little-endian, asynchronous read.
    // Dinh dang IMEM_FORMAT=1B (mac dinh cua makefile): moi dong trong file hex
    // la 1 byte, nap vao mang byte 'imem'.
    //
    // START_ADDR can theo kich thuoc vung nho (0x8000_0000 voi 19 hoac 26 bit),
    // nen offset = i_addr[ADDR_WIDTH-1:0], khong can phep tru.
    // PC luon chia het cho 4 nen 4 byte cua lenh nam o offset {word, 2'b00..2'b11},
    // ghep bang noi day thay cho phep cong.
    // ------------------------------------------------------------------
    logic [7:0]            imem [2**ADDR_WIDTH];
    logic [ADDR_WIDTH-1:2] word_addr;
    logic                  in_range;
    logic                  unused_clk;

    initial begin
        $readmemh(PROGRAMFILE, imem);
    end

    assign word_addr  = i_addr[ADDR_WIDTH-1:2];
    assign unused_clk = i_clk;      // doc bat dong bo: khong dung clock

    // Ngoai vung IMEM tra 0 (lenh khong hop le -> controller khong bao o_db_valid)
    assign in_range = (i_addr[31:ADDR_WIDTH] == START_ADDR[31:ADDR_WIDTH]);

    assign o_data = in_range ? {imem[{word_addr, 2'b11}],
                                imem[{word_addr, 2'b10}],
                                imem[{word_addr, 2'b01}],
                                imem[{word_addr, 2'b00}]}
                             : 32'h0000_0000;

endmodule
