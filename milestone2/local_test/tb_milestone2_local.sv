// Testbench cuc bo (khong thay the testbench cua TA).
//
// Quy tac timing: stimulus (o day chi co i_rstn) gan bang non-blocking ngay sau
// @(posedge clk). Khong dung #delay, khong dung negedge.
//
// Lay mau: ngay sau @(posedge clk) testbench doc tin hieu trong active region,
// tuc gia tri TRUOC canh len (DUT cap nhat thanh ghi o NBA region sau do). Voi
// single-cycle, gia tri truoc canh k chinh la lenh dang hoan thanh tai canh k:
// PC, o_db_valid, rd va du lieu ghi regfile. Moi canh so 1 dong trace cua golden
// model (gen_test.py). o_db_valid duoc dem ngay trong vong lay mau o moi canh len
// (giong testbench cua TA), moi canh dung 1 lan, khong co khoi always nao chay song song.
//
// Can simulator theo dung thu tu region cua IEEE 1800 (Icarus, Xcelium).
// Verilator khong theo thu tu nay khi doc tin hieu ngay tai canh clock.
//
//   +TRACE=<file> (mac dinh trace.hex)   +dump: ghi waveform
`timescale 1ns/1ps

module tb_milestone2_local;
    parameter logic [31:0] DMEM_START = 32'h8008_0000;
    parameter int unsigned IMEM_AW    = 19;
    localparam int MAX_TRACE = 400000;

    logic clk  = 1'b0;
    logic rstn = 1'b0;            // reset tu thoi diem 0
    logic db_valid;
    logic [31:0] dmem_addr, dmem_wdata;
    logic [3:0]  dmem_bmsk;
    logic        dmem_wren;

    milestone2_mock #(.DMEM_START(DMEM_START), .IMEM_AW(IMEM_AW)) dut (
        .i_clk        (clk),
        .i_rstn       (rstn),
        .o_db_valid   (db_valid),
        .o_dmem_addr  (dmem_addr),
        .o_dmem_wdata (dmem_wdata),
        .o_dmem_bmsk  (dmem_bmsk),
        .o_dmem_wren  (dmem_wren)
    );

    always #5 clk = ~clk;

    logic [31:0] t_pc  [MAX_TRACE];
    logic        t_vld [MAX_TRACE];
    logic        t_we  [MAX_TRACE];
    logic [4:0]  t_rd  [MAX_TRACE];
    logic [31:0] t_val [MAX_TRACE];
    int n_trace = 0, n_checks = 0, n_errors = 0;
    int n_valid = 0, n_cycles = 0, n_exp_valid = 0;

    // Tin hieu ben trong core de so sanh
    logic [31:0] pc;
    logic        we;
    logic [4:0]  rd;
    logic [31:0] wval;
    assign pc   = dut.u_core.pc;
    assign rd   = dut.u_core.instr[11:7];
    assign we   = dut.u_core.o_reg_wen && (rd != 5'd0);
    assign wval = dut.u_core.wb_data;

    task automatic err(input string msg);
        n_errors++;
        if (n_errors <= 20) $display("ERROR t=%0t %s", $time, msg);
    endtask

    initial begin
        string trace_f;
        int fd, r;
        logic [31:0] a_pc, a_val;
        logic [3:0]  a_vld, a_we;
        logic [7:0]  a_rd;
        logic        stop;

        if (!$value$plusargs("TRACE=%s", trace_f)) trace_f = "trace.hex";
        if ($test$plusargs("dump")) begin
            $dumpfile("tb_milestone2_local.vcd");
            $dumpvars(0, tb_milestone2_local);
        end
        fd = $fopen(trace_f, "r");
        if (fd == 0) $fatal(1, "khong mo duoc %s", trace_f);
        while (!$feof(fd)) begin
            r = $fscanf(fd, "%h %h %h %h %h\n", a_pc, a_vld, a_we, a_rd, a_val);
            if (r == 5) begin
                t_pc[n_trace] = a_pc;  t_vld[n_trace] = a_vld[0]; t_we[n_trace] = a_we[0];
                t_rd[n_trace] = a_rd[4:0]; t_val[n_trace] = a_val;
                n_exp_valid += a_vld[0];
                n_trace++;
            end
        end
        $fclose(fd);
        $display("[tb] DMEM_START=%h IMEM_AW=%0d, %0d instructions in trace", DMEM_START, IMEM_AW, n_trace);

        // ---- reset: o_db_valid phai = 0 trong suot thoi gian reset
        repeat (4) begin
            @(posedge clk);
            n_checks++;
            if (db_valid === 1'b1) n_valid++;
            if (db_valid !== 1'b0) err("o_db_valid = 1 trong luc reset");
        end
        rstn <= 1'b1;                       // nha reset ngay sau canh len (NBA)

        // ---- moi canh: lenh vua hoan thanh phai khop trace
        stop = 1'b0;
        for (int k = 0; k < n_trace; k++) begin
            if (!stop) begin
                @(posedge clk);
                n_checks++;
                n_cycles++;
                if (db_valid === 1'b1) n_valid++;
                if (pc !== t_pc[k]) begin
                    err($sformatf("#%0d PC=%h, mong doi %h", k, pc, t_pc[k]));
                    stop = 1'b1;
                end else begin
                    if (db_valid !== t_vld[k])
                        err($sformatf("#%0d PC=%h inst=%h: o_db_valid=%b, mong doi %b",
                                      k, pc, dut.u_core.instr, db_valid, t_vld[k]));
                    if (we !== t_we[k])
                        err($sformatf("#%0d PC=%h inst=%h: ghi regfile=%b, mong doi %b",
                                      k, pc, dut.u_core.instr, we, t_we[k]));
                    else if (t_we[k] && ((rd !== t_rd[k]) || (wval !== t_val[k])))
                        err($sformatf("#%0d PC=%h inst=%h: x%0d <= %h, mong doi x%0d <= %h",
                                      k, pc, dut.u_core.instr, rd, wval, t_rd[k], t_val[k]));
                    if (!t_vld[k] && (dmem_wren !== 1'b0))
                        err($sformatf("#%0d PC=%h: lenh illegal van ghi DMEM", k, pc));
                end
            end
        end
        n_checks++;
        if (n_valid !== n_exp_valid)
            err($sformatf("so lan o_db_valid = %0d, mong doi %0d", n_valid, n_exp_valid));
        $display("[tb] cycles = %0d, o_db_valid = %0d, lenh illegal co chu y = %0d",
                 n_cycles, n_valid, n_cycles - n_valid);
        if (n_errors == 0) $display("[tb] PASSED: %0d checks, 0 errors", n_checks);
        else               $display("[tb] FAILED: %0d checks, %0d errors", n_checks, n_errors);
        $finish;
    end
endmodule
