package fifo_tb_pkg;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  parameter int DATA_WIDTH = 8;
  parameter int FIFO_DEPTH = 16;

  class fifo_item extends uvm_sequence_item;
    rand bit                    wr_en;
    rand bit                    rd_en;
    rand bit [DATA_WIDTH-1:0]   wr_data;
         bit [DATA_WIDTH-1:0]   rd_data;
         bit                    full;
         bit                    empty;

    constraint useful_operation { wr_en || rd_en; }
    `uvm_object_utils_begin(fifo_item)
      `uvm_field_int(wr_en, UVM_DEFAULT)
      `uvm_field_int(rd_en, UVM_DEFAULT)
      `uvm_field_int(wr_data, UVM_DEFAULT)
      `uvm_field_int(rd_data, UVM_DEFAULT)
      `uvm_field_int(full, UVM_DEFAULT)
      `uvm_field_int(empty, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "fifo_item"); super.new(name); endfunction
  endclass

  class fifo_random_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_random_seq)
    function new(string name = "fifo_random_seq"); super.new(name); endfunction
    task body();
      repeat (100) begin
        req = fifo_item::type_id::create("req");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RAND", "Transaction randomization failed")
        finish_item(req);
      end
    endtask
  endclass

  class fifo_write_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_write_seq)
    function new(string name = "fifo_write_seq"); super.new(name); endfunction
    task body();
      repeat (FIFO_DEPTH + 2) begin
        req = fifo_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { wr_en == 1; rd_en == 0; })
          `uvm_fatal("RAND", "Write transaction randomization failed")
        finish_item(req);
      end
    endtask
  endclass

  class fifo_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_driver)
    virtual fifo_if #(DATA_WIDTH) vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fifo_if #(DATA_WIDTH))::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface was not supplied to driver")
    endfunction
    task run_phase(uvm_phase phase);
      vif.wr_en <= 0; vif.rd_en <= 0; vif.wr_data <= '0;
      forever begin
        seq_item_port.get_next_item(req);
        // Drive on the falling edge so inputs are stable for the next DUT edge.
        @(negedge vif.clk);
        vif.wr_en   <= req.wr_en;
        vif.rd_en   <= req.rd_en;
        vif.wr_data <= req.wr_data;
        @(negedge vif.clk);
        vif.wr_en <= 0; vif.rd_en <= 0;
        seq_item_port.item_done();
      end
    endtask
  endclass

  class fifo_monitor extends uvm_component;
    `uvm_component_utils(fifo_monitor)
    virtual fifo_if #(DATA_WIDTH) vif;
    uvm_analysis_port #(fifo_item) ap;
    function new(string name, uvm_component parent); super.new(name, parent); ap = new("ap", this); endfunction
    function void build_phase(uvm_phase phase);
      if (!uvm_config_db#(virtual fifo_if #(DATA_WIDTH))::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface was not supplied to monitor")
    endfunction
    task run_phase(uvm_phase phase);
      fifo_item item;
      forever begin
        @(posedge vif.clk);
        #1step; // Sample after the DUT's nonblocking updates.
        if (vif.rst_n && (vif.wr_en || vif.rd_en)) begin
          item = fifo_item::type_id::create("item");
          item.wr_en   = vif.wr_en;
          item.rd_en   = vif.rd_en;
          item.wr_data = vif.wr_data;
          item.rd_data = vif.rd_data;
          item.full    = vif.full;
          item.empty   = vif.empty;
          ap.write(item);
        end
      end
    endtask
  endclass

  class fifo_agent extends uvm_agent;
    `uvm_component_utils(fifo_agent)
    uvm_sequencer #(fifo_item) seqr;
    fifo_driver drv;
    fifo_monitor mon;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      mon = fifo_monitor::type_id::create("mon", this);
      if (is_active == UVM_ACTIVE) begin
        seqr = uvm_sequencer#(fifo_item)::type_id::create("seqr", this);
        drv  = fifo_driver::type_id::create("drv", this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      if (is_active == UVM_ACTIVE) drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  class fifo_scoreboard extends uvm_component;
    `uvm_component_utils(fifo_scoreboard)
    uvm_analysis_imp #(fifo_item, fifo_scoreboard) imp;
    bit [DATA_WIDTH-1:0] expected_q[$];
    int unsigned writes, reads, errors;
    function new(string name, uvm_component parent); super.new(name, parent); imp = new("imp", this); endfunction
    function void write(fifo_item item);
      bit can_write, can_read;
      // Determine legality from the reference model's *pre-operation* depth.
      can_write = item.wr_en && (expected_q.size() < FIFO_DEPTH);
      can_read  = item.rd_en && (expected_q.size() > 0);
      if (can_write) begin expected_q.push_back(item.wr_data); writes++; end
      if (can_read) begin
        bit [DATA_WIDTH-1:0] expected;
        expected = expected_q.pop_front(); reads++;
        if (item.rd_data !== expected) begin
          errors++;
          `uvm_error("FIFO_MISMATCH", $sformatf("Expected 0x%0h, got 0x%0h", expected, item.rd_data))
        end
      end
      if (item.full !== (expected_q.size() == FIFO_DEPTH)) begin
        errors++;
        `uvm_error("FULL_FLAG", $sformatf("full=%0b, expected %0b", item.full, expected_q.size() == FIFO_DEPTH))
      end
      if (item.empty !== (expected_q.size() == 0)) begin
        errors++;
        `uvm_error("EMPTY_FLAG", $sformatf("empty=%0b, expected %0b", item.empty, expected_q.size() == 0))
      end
    endfunction
    function void report_phase(uvm_phase phase);
      `uvm_info("FIFO_SB", $sformatf("writes=%0d reads=%0d queued=%0d errors=%0d", writes, reads, expected_q.size(), errors), UVM_NONE)
    endfunction
  endclass

  class fifo_env extends uvm_env;
    `uvm_component_utils(fifo_env)
    fifo_agent agent;
    fifo_scoreboard sb;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      agent = fifo_agent::type_id::create("agent", this);
      sb    = fifo_scoreboard::type_id::create("sb", this);
    endfunction
    function void connect_phase(uvm_phase phase); agent.mon.ap.connect(sb.imp); endfunction
  endclass

  class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test)
    fifo_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env = fifo_env::type_id::create("env", this); endfunction
    task run_phase(uvm_phase phase);
      fifo_random_seq seq = fifo_random_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.seqr);
      #20;
      phase.drop_objection(this);
    endtask
  endclass

  class fifo_write_test extends fifo_base_test;
    `uvm_component_utils(fifo_write_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
      fifo_write_seq seq = fifo_write_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.seqr);
      #20;
      phase.drop_objection(this);
    endtask
  endclass
endpackage
