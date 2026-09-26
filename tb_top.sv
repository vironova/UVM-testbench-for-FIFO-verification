module tb_top;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import fifo_tb_pkg::*;
  logic clk = 0;
  always #5 clk = ~clk;

  fifo_if #(DATA_WIDTH) fifo_vif(clk);

  sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(FIFO_DEPTH)) dut (
    .clk(clk), .rst_n(fifo_vif.rst_n), .wr_en(fifo_vif.wr_en), .rd_en(fifo_vif.rd_en),
    .wr_data(fifo_vif.wr_data), .rd_data(fifo_vif.rd_data), .full(fifo_vif.full), .empty(fifo_vif.empty)
  );

  initial begin
    fifo_vif.rst_n = 0;
    fifo_vif.wr_en = 0;
    fifo_vif.rd_en = 0;
    fifo_vif.wr_data = '0;
    repeat (3) @(posedge clk);
    fifo_vif.rst_n = 1;
  end

  initial begin
    uvm_config_db#(virtual fifo_if #(DATA_WIDTH))::set(null, "uvm_test_top.env.agent.*", "vif", fifo_vif);
    run_test();
  end
endmodule
