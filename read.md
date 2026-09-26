# UVM FIFO Verification Testbench

This project verifies a parameterized synchronous FIFO using UVM. It is intentionally compact but follows the standard hierarchy:

```text
tb_top → fifo interface → DUT
                         ↳ UVM test → environment → agent → driver / monitor
                                                   ↘ scoreboard
```

## Contents

| File | Purpose |
|---|---|
| `sync_fifo.sv` | Parameterized synchronous FIFO DUT. |
| `fifo_if.sv` | Clocked virtual interface shared by DUT and UVM components. |
| `fifo_tb_pkg.sv` | Transaction, sequences, driver, monitor, agent, scoreboard, environment, and tests. |
| `tb_top.sv` | Generates clock/reset, instantiates the DUT, and sets the virtual interface in `uvm_config_db`. |
| `filelist.f` | Generic compilation order. |
| `Makefile` | Example Questa/ModelSim commands. |

## What is verified

- Normal FIFO write/read ordering.
- Random simultaneous and individual reads/writes.
- Empty and full boundary behavior.
- A write-only fill test that attempts `DEPTH + 2` writes, confirming that writes while full are rejected.

The scoreboard keeps a reference queue. A legal write pushes into the queue; a legal read pops the expected value and compares it with the DUT output. It also checks the post-operation `full` and `empty` flags against the reference depth. Any ordering or data error is reported through UVM errors such as `FIFO_MISMATCH` or `FULL_FLAG`.

## Running

The project requires a SystemVerilog simulator with UVM 1.2-compatible libraries. For Questa/ModelSim, point `UVM_HOME` to the UVM source directory and run:

```powershell
make random UVM_HOME=<path-to-uvm>
make write  UVM_HOME=<path-to-uvm>
```

Or compile the files in `filelist.f` and select a test with:

```text
+UVM_TESTNAME=fifo_base_test
+UVM_TESTNAME=fifo_write_test
```

## Config DB flow

`tb_top` places `fifo_vif` in the configuration database:

```systemverilog
uvm_config_db#(virtual fifo_if #(DATA_WIDTH))::set(
  null, "uvm_test_top.env.agent.*", "vif", fifo_vif);
```

The driver and monitor retrieve the same handle in `build_phase`. This keeps pin-level access out of the sequence and test classes.

## Extending it

Add directed sequences for overflow, underflow, simultaneous read/write at full or empty, or reset while traffic is active. Coverage can be added in `fifo_monitor` for operation types and flag transitions.
