# 4-bit ALU (Verilog, for Vivado)

Design sources (add all 9 with Add Sources -> Add or create design sources):
  alu_4bit.v (TOP), control_unit.v, adder_subtractor_4bit.v, full_adder.v,
  logic_unit_4bit.v, shifter_4bit.v, muldiv_unit.v, result_mux.v, flag_unit.v

Simulation source (Add Sources -> Add or create simulation sources):
  alu_4bit_tb.v (TOP of simulation)

Run: Run Simulation -> Run Behavioral Simulation -> click "Run All".
The Tcl Console should end with:
  PASS: 3584 single-cycle checks + 512 MUL/DIV checks, 0 errors

See Verilog_Vivado_Easy_Guide.pdf for step-by-step help,
and ALU_4bit_Report.pdf for the full theory.
