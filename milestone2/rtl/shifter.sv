// Exercise 3: 32-bit shifter (logical right, logical left, arithmetic right).
//
// Architecture: logarithmic barrel shifter. Five 2:1 mux stages shift right by
// 1, 2, 4, 8 and 16 positions; stage k is enabled by i_shamt[k]. A single
// right-shift datapath serves all three operations:
//   logical right    : the vacated upper bits are filled with 0
//   arithmetic right : the vacated upper bits are filled with the sign bit
//   logical left     : the operand is bit-reversed, shifted right with a 0 fill,
//                      and the result is bit-reversed again
// Bit reversal is only wiring. No shift operator and no function is used in this file.

module shifter (
  input  logic [31:0] i_data,
  input  logic [4:0]  i_shamt,
  input  logic [1:0]  i_mode,
  output logic [31:0] o_data
);

  // i_mode encoding (Table 4 of the specification)
  localparam logic [1:0] MODE_SRL  = 2'b00;
  localparam logic [1:0] MODE_SLL  = 2'b01;
  localparam logic [1:0] MODE_SRA  = 2'b10;
  localparam logic [1:0] MODE_RSVD = 2'b11;

  // Value driven on o_data for the reserved mode
  localparam logic [31:0] SAFE_VALUE = 32'h0000_0000;


  logic        is_left;
  logic        fill;       // bit inserted at the MSB side
  logic [31:0] stage_in;
  logic [31:0] s1, s2, s4, s8, s16;
  logic [31:0] s16_reversed;
  logic [31:0] data_reversed;

  assign is_left = (i_mode == MODE_SLL);
  assign fill    = (i_mode == MODE_SRA) & i_data[31];

  // Dao bit chi la noi day (khong dung function)
  assign data_reversed = {i_data[0], i_data[1], i_data[2], i_data[3], i_data[4], i_data[5], i_data[6], i_data[7], i_data[8], i_data[9], i_data[10], i_data[11], i_data[12], i_data[13], i_data[14], i_data[15], i_data[16], i_data[17], i_data[18], i_data[19], i_data[20], i_data[21], i_data[22], i_data[23], i_data[24], i_data[25], i_data[26], i_data[27], i_data[28], i_data[29], i_data[30], i_data[31]};

  assign stage_in = is_left ? data_reversed : i_data;

  // Right-shift mux stages
  assign s1  = i_shamt[0] ? {fill,        stage_in[31:1]} : stage_in;
  assign s2  = i_shamt[1] ? {{2{fill}},   s1[31:2]}       : s1;
  assign s4  = i_shamt[2] ? {{4{fill}},   s2[31:4]}       : s2;
  assign s8  = i_shamt[3] ? {{8{fill}},   s4[31:8]}       : s4;
  assign s16 = i_shamt[4] ? {{16{fill}},  s8[31:16]}      : s8;

  assign s16_reversed = {s16[0], s16[1], s16[2], s16[3], s16[4], s16[5], s16[6], s16[7], s16[8], s16[9], s16[10], s16[11], s16[12], s16[13], s16[14], s16[15], s16[16], s16[17], s16[18], s16[19], s16[20], s16[21], s16[22], s16[23], s16[24], s16[25], s16[26], s16[27], s16[28], s16[29], s16[30], s16[31]};

  // Output selection
  always_comb begin
    unique case (i_mode)
      MODE_SRL,
      MODE_SRA:  o_data = s16;
      MODE_SLL:  o_data = s16_reversed;
      MODE_RSVD: o_data = SAFE_VALUE;
      default:   o_data = SAFE_VALUE;
    endcase
  end

endmodule
