module sync_fifo #(
  parameter int DATA_WIDTH = 8,
  parameter int DEPTH = 16,
  parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  wr_en,
  input  logic                  rd_en,
  input  logic [DATA_WIDTH-1:0] wr_data,
  output logic [DATA_WIDTH-1:0] rd_data,
  output logic                  full,
  output logic                  empty
);
  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
  logic [$clog2(DEPTH+1)-1:0] count;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr  <= '0;
      rd_ptr  <= '0;
      count   <= '0;
      rd_data <= '0;
    end else begin
      case ({wr_en && !full, rd_en && !empty})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
      if (wr_en && !full) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr <= wr_ptr + 1'b1;
      end
      if (rd_en && !empty) begin
        rd_data <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end
    end
  end
endmodule
