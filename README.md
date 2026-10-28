# Formal verification of the FFT IP with `vyges formal`

A complete, reproducible **formal property campaign** on the Vyges
[FFT accelerator](https://github.com/vyges/fast-fourier-transform-ip) as it is integrated in the
[Edge Sensor SoC](https://github.com/vyges/vyges-edge-sensor-soc). It was run with one command,
and it covers the reset behaviour, completion, memory addressing, scaling, bus protocol and
interrupts of the design. The results are in [`report/report.md`](report/report.md).

Everything needed to re-run it is here: the manifest, the four monitors, and the commands below.

## Why run formal next to simulation

Simulation and formal answer different questions, and a design needs both.

- **Simulation** shows the design does the right thing on the stimulus someone wrote. Its coverage
  is only as good as the tests, and a defect that needs an unusual sequence of events can sit
  unseen behind thousands of passing cycles.
- **A property** states a rule the design must keep — "every data write lands inside the
  configured buffer" — and the prover checks it against **every** input sequence from reset. It
  either proves the rule or returns a counterexample: the exact cycle-by-cycle inputs that break it.

So formal is not a replacement for a testbench. It is a fast way to find where the testbench
should look. Each counterexample here is short, concrete and already replayed in simulation, which
makes it a ready-made directed test: the DV team writes the test from it, the designer fixes the
RTL, and both the test and the property guard the fix from then on. Finding these defects early,
from the RTL alone, avoids the long regressions and late debug they would otherwise cost.

## What this campaign found

Run on the SoC's RTL at commit
[`df18c6d`](https://github.com/vyges/vyges-edge-sensor-soc/commit/df18c6d4abc2c5731efadc95d43d08132cd4ead0)
(1024-point build, 16-bit data and twiddles):

| | |
|---|---|
| properties proved for every input sequence | 14 |
| properties failing, with a counterexample | 9 |
| covers reached (the assumptions do not hide the behaviour) | 6 of 8 (one unreachable, one undecided) |
| counterexamples confirmed by replay in Verilator | all |
| mutants caught by the property set | 10 of 10 |

The failures and the one unreachable cover trace back to five design defects:

| claim | defect |
|---|---|
| C2 completion | The length configuration is re-sampled on every cycle START is high, so a CONFIG write during a run changes N under the running engine and DONE can be raised early. |
| C4 addressing | Result writes share one registered SRAM address with three reads and lose that arbitration, so a butterfly result can be written to a read address — including into the twiddle bank. The pipeline is not flushed by reset, so in-flight writes can land after the engine stops. |
| C5 scaling | The scale factor counts overflowing butterflies, not stages, in an 8-bit register, so it wraps and the exponent read back is wrong for blocks with frequent overflow. |
| C6 interrupts | INT_STATUS[0] clears itself the cycle after it is set, so software almost never sees it, and there is no write-1-to-clear path. |
| error path | The RUN → ERROR transition is guarded by a signal decoded from the ERROR state itself, so the engine can never report an error — proved for every input sequence. |

Each finding is recorded in the manifest with `expect` set to the failing result, so the report
reads it as **FINDING**, never as a pass. The report always names the RTL commit it was run on.

## After the fixes

Each counterexample above became a directed test and an RTL fix in the
[FFT IP repository](https://github.com/vyges/fast-fourier-transform-ip):

| commit | fix |
|---|---|
| [`5974811`](https://github.com/vyges/fast-fourier-transform-ip/commit/5974811) | APB address decode: data samples 512 to 1023 no longer overwrite the twiddle table |
| [`69f184a`](https://github.com/vyges/fast-fourier-transform-ip/commit/69f184a) | engine: configuration latched at launch, length checked (an illegal length now reports ERROR), one memory access per cycle in a fixed butterfly sequence, abort clears in-flight writes, scaling counted per stage, bit-reverse reorder pass |
| [`acc2eaf`](https://github.com/vyges/fast-fourier-transform-ip/commit/acc2eaf) | interrupts and status: INT_STATUS is write-1-to-clear and holds until cleared, FFT_STATUS.done holds until the next run |
| [`8317b30`](https://github.com/vyges/fast-fourier-transform-ip/commit/8317b30) | a bit-exact golden-model regression, on the RTL and on the synthesized netlist |

The [`fixed-ip/`](fixed-ip) campaign re-checks the same claims on the IP itself at
[`60dcb55`](https://github.com/vyges/fast-fourier-transform-ip/commit/60dcb55cfcc0d55824a15f86ecb0847d6cb4a625)
(the engine, register block and interrupt controller behind its own APB port, with the SoC's SRAM
banks modelled beside it). Its report is in [`fixed-ip/report/report.md`](fixed-ip/report/report.md):

| | |
|---|---|
| properties proved for every input sequence | 18 |
| properties failing | 0 |
| covers reached | 6 of 7 |
| mutants caught by the property set | 14 of 14 |

Every claim that failed on the SoC commit now holds. Four of the mutants reinstate a defect that
formal found, one at a time: re-sampling the configuration, counting scaled butterflies instead of
scaled stages, an interrupt bit that clears itself, and a DONE status that lasts one cycle. Each is
caught. So the properties guard each fix from now on, next to the directed test that reproduces
it. Two claims are deeper than a proof can reach in 30 minutes, and the report says so:

- C3: a legal-length run completes within its bound.
- The cover of a full 256-point run completing.

Completion of legal lengths is covered instead by the golden-model regression in simulation.

## What is in this repository

| path | what |
|---|---|
| [`manifest.toml`](manifest.toml) | the campaign: the RTL and its parameters, the assumptions, every property, cover and mutant, and the findings |
| [`monitors/`](monitors) | plain Verilog monitors, each spliced into the module it watches so it reads that module's signals by name |
| [`report/`](report) | the report: summary, findings, every counterexample, covers, mutants, lint and the exact tool versions |
| [`fixed-ip/`](fixed-ip) | the campaign on the fixed IP: its manifest, monitors, the formal wrapper and SRAM model, and its [report](fixed-ip/report/report.md) |

A monitor names its claims by convention: `vf_p_<id>` is 1 when property `<id>` is violated,
`vf_c_<id>` is 1 when cover `<id>` is hit, and `vf_a_<id>` is 0 when assumption `<id>` is broken.

## Run it yourself

Install the Vyges CLI and the physical engines, which include `vyges formal` and its prover:

```sh
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/vyges-tools/cli/releases/latest/download/vyges-installer.sh | sh
# or: brew install vyges/tap/vyges
vyges install physical
```

The campaign also needs [Yosys](https://github.com/YosysHQ/yosys) and
[Verilator](https://github.com/verilator/verilator) on `PATH`, and the sky130 `sky130_fd_sc_hd`
typical-corner Liberty (the manifest reads it from `$PDK_ROOT`; `--liberty FILE` overrides it).

```sh
git clone https://github.com/vyges/vyges-edge-sensor-soc
git -C vyges-edge-sensor-soc checkout df18c6d4abc2c5731efadc95d43d08132cd4ead0
git clone https://github.com/vyges-ip-tests/fast-fourier-transform-ip-formal
cd fast-fourier-transform-ip-formal

vyges formal run manifest.toml --out formal-out                 # prove, replay, mutate, report
vyges formal replay manifest.toml c6_int_status_held --out formal-out --show u_fft_top.fft_control_inst.fft_done_pending
vyges formal report manifest.toml --out formal-out              # re-render after editing expectations
```

Exit status: 0 when every result is as expected, 2 when anything is not, 1 on a tool error. A full
run includes the mutants, each re-synthesized and re-proved, and two deep checks that are expected
to time out (see below).

## What the results do and do not claim

Every claim holds only under the assumptions it lists, which are stated in the report:

- **`start_once`** — once software drops START during a run, it does not raise it again until the
  engine is idle.
- **`legal_len`** — whenever START is high, the programmed length is legal for this build
  (256 to 1024 points).
- **`no_abort`** — a run is never aborted by `CTRL.reset` or a second block reset.

And within these limits:

- SRAM read data is unconstrained: every claim is a control, address or protocol claim that must
  hold for **any** data. End-to-end numerical correctness of a transform is not claimed.
- Proofs start from the all-zero register state after reset. Registers without a reset (listed in
  the report's lint section) are an assumption in the model, not a proof.
- The bounded-completion claim (C3: a legal run ends within 5300 cycles) is undecided at its
  30-minute limit and is reported as such, never as a pass. So is the cover for a legal run that
  completes without an abort, about 1,300 cycles deep: it was reached once, then not within one or
  two hours. For the fixed IP, completion of legal runs is shown by its bit-exact golden-model
  regression instead.
- The results are for this RTL commit and configuration, and say nothing about timing closure.

## License

Apache-2.0. See [LICENSE](LICENSE).
