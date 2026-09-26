interface fifo_if #(parameter int DATA_WIDTH = 8) (input logic clk);
  logic rst_n;
  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  logic [DATA_WIDTH-1:0] rd_data;
  logic full;
  logic empty;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output wr_en, rd_en, wr_data;
    input rd_data, full, empty;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input rst_n, wr_en, rd_en, wr_data, rd_data, full, empty;
  endclocking
endinterface
