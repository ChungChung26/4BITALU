// ============================================================
// alu_4bit_tb.v
// Testbench for alu_4bit.
//  Part 1: prints example operations, including MUL and DIV.
//  Part 2: checks every single-cycle op on all 256 (a,b) pairs.
//  Part 3: checks MUL and DIV on all 256 (a,b) pairs, including
//          the latency and divide-by-zero.
//
// HOW TO RUN IN VIVADO
//   1. Add this file as a SIMULATION source.
//   2. Flow Navigator -> Run Simulation -> Run Behavioral Simulation.
//   3. The simulation stops after 1000 ns by default. Click
//      "Run All" (or type  run all  in the Tcl Console) so the
//      whole test runs (about 35 us). Results print in the Tcl Console.
// ============================================================
`timescale 1ns/1ps

module alu_4bit_tb;
    reg        clk = 0, rst = 1, start = 0;
    reg  [3:0] a = 0, b = 0, opcode = 0;
    wire [7:0] result;
    wire       carry, zero, overflow, negative, div_by_zero, busy, done;

    alu_4bit dut (
        .clk(clk), .rst(rst), .start(start),
        .a(a), .b(b), .opcode(opcode),
        .result(result), .carry(carry), .zero(zero),
        .overflow(overflow), .negative(negative),
        .div_by_zero(div_by_zero), .busy(busy), .done(done)
    );

    always #5 clk = ~clk;          // 100 MHz clock (10 ns period)

    // ---------------- reference model for single-cycle ops ----------------
    reg [3:0] exp_r;
    reg       exp_c, exp_v;
    reg [4:0] t;
    task model;
        begin
            exp_c = 0; exp_v = 0; exp_r = 0;
            case (opcode)
                4'b0000: begin t = {1'b0,a} + {1'b0,b};        exp_r = t[3:0]; exp_c = t[4];
                               exp_v = (a[3] == b[3]) && (exp_r[3] != a[3]); end
                4'b0001: begin t = {1'b0,a} + {1'b0,~b} + 5'd1; exp_r = t[3:0]; exp_c = t[4];
                               exp_v = (a[3] != b[3]) && (exp_r[3] != a[3]); end
                4'b0010: exp_r = a & b;
                4'b0011: exp_r = a | b;
                4'b0100: exp_r = a ^ b;
                4'b0101: exp_r = ~a;
                4'b0110: begin exp_r = {a[2:0], 1'b0}; exp_c = a[3]; end
                4'b0111: begin exp_r = {1'b0, a[3:1]}; exp_c = a[0]; end
                default: exp_r = 0;
            endcase
        end
    endtask

    // ---------------- run one MUL or DIV, count clock cycles ----------------
    integer cycles;
    task run_md(input [3:0] op, input [3:0] x, input [3:0] y);
        begin
            @(negedge clk);
            opcode = op; a = x; b = y; start = 1;
            @(negedge clk);
            start = 0; cycles = 0;
            while (!done) begin @(negedge clk); cycles = cycles + 1; end
        end
    endtask

    task show_comb(input [3:0] op, input [3:0] x, input [3:0] y, input [8*4-1:0] name);
        begin
            opcode = op; a = x; b = y; #1;
            $display(" %s %b | %2d  %2d | %b (%3d) | C=%b Z=%b V=%b N=%b",
                     name, op, x, y, result, result, carry, zero, overflow, negative);
        end
    endtask

    task show_md(input [3:0] op, input [3:0] x, input [3:0] y, input [8*4-1:0] name);
        begin
            run_md(op, x, y);
            if (op == 4'b1000)
                $display(" %s %b | %2d  %2d | %b (%3d) | product = %0d, %0d cycles",
                         name, op, x, y, result, result, result, cycles + 1);
            else
                $display(" %s %b | %2d  %2d | %b       | quotient = %0d, remainder = %0d, dbz=%b, %0d cycles",
                         name, op, x, y, result, result[3:0], result[7:4], div_by_zero, cycles + 1);
        end
    endtask

    integer i, errors, op_i;
    reg [7:0] ab;               // loop value split into a (ab[7:4]) and b (ab[3:0])

    initial begin
        #12 rst = 0;

        // ---------------- Part 1: examples ----------------
        $display("\n Op   code |  A   B |  result        | flags / notes");
        $display(" ----------+--------+----------------+------------------------------");
        show_comb(4'b0000,  5,  3, "ADD ");
        show_comb(4'b0000, 15,  1, "ADD ");
        show_comb(4'b0001,  5,  3, "SUB ");
        show_comb(4'b0001,  3,  5, "SUB ");
        show_comb(4'b0010, 12, 10, "AND ");
        show_comb(4'b0011, 12, 10, "OR  ");
        show_comb(4'b0100, 12, 10, "XOR ");
        show_comb(4'b0101, 12,  0, "NOT ");
        show_comb(4'b0110, 11,  0, "SHL ");
        show_comb(4'b0111, 11,  0, "SHR ");
        show_md  (4'b1000, 13, 11, "MUL ");
        show_md  (4'b1000, 15, 15, "MUL ");
        show_md  (4'b1001, 13,  4, "DIV ");
        show_md  (4'b1001, 15,  3, "DIV ");
        show_md  (4'b1001,  9,  0, "DIV ");

        errors = 0;

        // ---------------- Part 2: every single-cycle op, all inputs ----------------
        for (op_i = 0; op_i < 16; op_i = op_i + 1) begin
            if (op_i != 8 && op_i != 9) begin
                for (i = 0; i < 256; i = i + 1) begin
                    opcode = op_i; {a, b} = i; #1;
                    model;
                    if (result !== {4'b0, exp_r} || carry !== exp_c || overflow !== exp_v ||
                        zero !== (exp_r == 0) || negative !== exp_r[3]) begin
                        errors = errors + 1;
                        if (errors <= 10)
                            $display("FAIL op=%b a=%0d b=%0d got %b expected %b", opcode, a, b, result, exp_r);
                    end
                end
            end
        end

        // ---------------- Part 3: MUL and DIV, all inputs ----------------
        for (i = 0; i < 256; i = i + 1) begin
            ab = i;
            run_md(4'b1000, ab[7:4], ab[3:0]);
            if (result !== ab[7:4] * ab[3:0] || cycles + 1 != 5 || zero !== (result == 0)) begin
                errors = errors + 1;
                if (errors <= 10) $display("FAIL MUL %0d*%0d got %0d", ab[7:4], ab[3:0], result);
            end
            run_md(4'b1001, ab[7:4], ab[3:0]);
            if (ab[3:0] == 0) begin
                if (div_by_zero !== 1 || result[3:0] !== 4'b1111 || result[7:4] !== ab[7:4]) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("FAIL DIV %0d/0", ab[7:4]);
                end
            end
            else if (result[3:0] !== ab[7:4] / ab[3:0] || result[7:4] !== ab[7:4] % ab[3:0] ||
                     div_by_zero !== 0) begin
                errors = errors + 1;
                if (errors <= 10) $display("FAIL DIV %0d/%0d got q=%0d r=%0d",
                                           ab[7:4], ab[3:0], result[3:0], result[7:4]);
            end
        end

        if (errors == 0)
            $display("\nPASS: 3584 single-cycle checks + 512 MUL/DIV checks, 0 errors\n");
        else
            $display("\nFAILED: %0d errors\n", errors);
        $finish;
    end
endmodule
