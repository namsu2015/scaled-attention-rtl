# Scaled Dot-Product Attention RTL

This repository implements fixed-point scaled dot-product attention in SystemVerilog:

```text
Q = XWQ
K = XWK
V = XWV
S = QK^T / sqrt(d_k)
A = softmax(S)
O = AV
```

The default configuration uses two tokens and a dimension of four. The pipelined core is the main design. A small sequential baseline is included only for a direct latency and resource-structure comparison.

## Files

```text
rtl/attention_core.sv              Pipelined attention RTL (main design)
rtl/attention_core_sequential.sv   Sequential comparison baseline
tb/tb_attention.sv        Self-checking testbench
scripts/golden_model.py   Bit-accurate reference model
data/*.hex                Input and expected-output files
results/output_*.txt      Simulation outputs
results/attention_*.vcd   Waveforms
Makefile                  Simulation commands
```

## Run

Install Python 3, Icarus Verilog, and Make. Then run:

```sh
make test
```

Expected result:

```text
Pipelined: 8 cycles, PASS
Sequential: 141 cycles, PASS
Both result files match the bit-accurate Python model
```

## Test example

Inputs use signed 8-bit values with four fractional bits.

```text
X = [[16,  0, 16,  0],
     [ 0, 16,  0, 16]]

WQ = WK = 16 * identity

WV = [[16,  8,  0,  0],
      [ 0, 16,  8,  0],
      [ 0,  0, 16,  8],
      [ 8,  0,  0, 16]]
```

The output is:

```text
14 10 14 10
10 14 10 14
```

Divide these values by 16 to obtain the real-valued output.

## Fixed-point formats

| Value | Format |
|---|---|
| X and weights | signed 8-bit, 4 fractional bits |
| Q, K, V, O | signed 16-bit, 4 fractional bits |
| Scores | signed 24-bit, 4 fractional bits |
| Attention weights | unsigned Q0.8 |
| Accumulators | signed 64-bit |

Requantization uses symmetric round-to-nearest with ties away from zero. Stored results saturate at their destination width instead of wrapping.

For `D=4`, the scale constant is:

```text
SCALE_MUL_Q = round((1 / sqrt(4)) * 256) = 128
```

## Softmax

Each score row first subtracts its maximum. An exponential lookup table covers values from 0 to -5.5 in steps of 0.5. The Q0.8 weights are calculated with:

```text
A[i] = round(exp[i] * 256 / sum(exp))
```

The RTL uses the synthesizable `/` operator. A larger design would normally replace it with a reciprocal LUT or a multi-cycle reciprocal unit.

## Pipeline

The pipeline stages are:

```text
1. X*W products for Q, K, and V
2. Q/K/V reduction and requantization
3. Q*K products
4. Score reduction and scaling
5. Row maximum
6. Exponential lookup and sum
7. Weight normalization
8. Weight*V products
9. Output reduction and requantization
```

The output stage completes eight clock periods after the launch edge. Matrix elements are spatially unrolled, so this version uses more hardware in exchange for low latency. The default RTL exposes 128 multiply operations before synthesis optimization. Area, maximum frequency, and power require a synthesis report and are not estimated here.

## Implementation comparison

Both implementations were simulated with the same `N=2`, `D=4` vector and produce the same bit-exact output.

| Design | Measured latency | Datapath structure | Main tradeoff |
|---|---:|---|---|
| Sequential baseline | 141 cycles | Reuses a multiply-accumulate path across loop indices | Lower structural parallelism, higher latency |
| Pipelined core | 8 cycles | Spatially unrolls matrix products across registered stages | Lower latency, substantially more multipliers and registers |

The cycle figures are Icarus Verilog simulation results from accepted `start` to `done`; they are not post-synthesis timing results. Run `make test` to reproduce both measurements.

## File format

Input files contain one hexadecimal two's-complement value per line in row-major order. The testbench loads them with `$readmemh`, runs each core, compares every output with `data/expected_o.hex`, and writes separate output and VCD files under `results/`.

## Parameter changes

`N`, `D`, and the arithmetic widths are parameters in the RTL. When D changes, update:

```text
SCALE_MUL_Q = round(256 / sqrt(D))
```

The testbench and Python model currently use fixed `N=2, D=4` constants and must be updated together for another shape.

## Limitations

- One deterministic test vector is included.
- The normalization divider is combinational.
- Full unrolling is intended for this small example; larger dimensions need tiling and memory reuse.
- No synthesis, timing, area, or power result is claimed.

## License

MIT
