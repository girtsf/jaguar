// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Regression harness for the device log pipeline over the network. It drives the
// real `jag` CLI against a live device and asserts on the monitored output.
//
// This is a hardware test: it needs a reachable Jaguar device and is not part of
// the default `make test`. See the `regtest` target in the Makefile. Run
// `toit run tests/regtest/run.toit -- --help` for the available options.
//
// Assertions use the throwing `check*` helpers from check.toit (not the `expect`
// package), because `expect` failures abort the whole program; throwing lets each
// scenario fail independently and the suite report a summary.

import cli
import .check show *
import .jag show JagRunner detect-sole-device
import .utils show *

DEFAULT-JAG ::= "jag"
DEFAULT-FIXTURES ::= "tests/regtest/fixtures"

main args/List:
  cmd := cli.Command "regtest"
      --help="""
          Regression suite for the device log pipeline over the network.

          Drives the real `jag` CLI against a live device and asserts on the
          monitored output."""
      --options=[
        cli.OptionString "jag"
            --default=DEFAULT-JAG
            --help="jag binary to invoke.",
        cli.OptionString "fixtures"
            --default=DEFAULT-FIXTURES
            --help="Directory holding the fixture .toit files.",
      ]
      --rest=[
        cli.OptionString "device"
            --help="Device name/id/address (jag -d). If omitted, the sole visible device is used.",
      ]
      --run=:: run-suite it
  cmd.run args

run-suite invocation/cli.Invocation -> none:
  bin/string := invocation["jag"]
  fixtures/string := invocation["fixtures"]
  device/string? := invocation["device"]

  // With no explicit device, fall back to the sole visible one (or fail loudly).
  if not device:
    device = detect-sole-device bin
    print "Auto-selected device: $device"

  jag := JagRunner bin device

  // Ordered so the no-filter scenario runs on a fresh buffer (before the filter
  // scenario reuses the same containers) and the flood runs last (its large
  // backlog would slow every later cursor-0 replay).
  failures := 0
  failures += run-scenario "1: run -m levels + exit marker":   scenario-levels jag fixtures
  failures += run-scenario "2: run -m min-log-level WARN":     scenario-min-level jag fixtures
  failures += run-scenario "3: run -m crash trace + exit":     scenario-crash jag fixtures
  failures += run-scenario "5: no-filter interleave":          scenario-interleave jag fixtures
  failures += run-scenario "4: two-container filter":          scenario-filter jag fixtures
  failures += run-scenario "7: cursor-0 replay exit markers":  scenario-replay jag fixtures
  failures += run-scenario "6: flood (no drop / no OOM)":      scenario-flood jag fixtures

  print ""
  if failures == 0:
    print "All scenarios passed."
  else:
    print "$failures scenario(s) FAILED."
    exit 1

run-scenario name/string [block] -> int:
  print "=== $name ==="
  e := catch: block.call
  if e != null:
    print "  FAIL: $e"
    return 1
  print "  PASS"
  return 0

// Scenario 1: `jag run -m emit` over the network. With the default INFO floor
// the debug line is dropped while print/info/warn/error are captured, and the
// run stops at the program's exit, printing a single inline exit marker.
scenario-levels jag/JagRunner fixtures/string -> none:
  jag.cleanup
  out := jag.run-monitored "$fixtures/emit.toit"
  expect-present out "JNET-print"
  expect-present out "JNET-info"
  expect-present out "JNET-warn"
  expect-present out "JNET-error"
  expect-missing out "JNET-debug"    // below the INFO floor
  expect-present out "program stopped - exit code 0"
  check-eq 1 (count-occurrences out "program stopped") --what="exit markers"

// Scenario 2: same run with `--min-log-level WARN`. The buffer floor now also
// drops info; only warn/error survive among the leveled logs, while print
// (which has no level) is always captured.
scenario-min-level jag/JagRunner fixtures/string -> none:
  jag.cleanup
  out := jag.run-monitored "$fixtures/emit.toit" --extra=["--min-log-level", "WARN"]
  expect-present out "JNET-print"
  expect-present out "JNET-warn"
  expect-present out "JNET-error"
  expect-missing out "JNET-info"     // below the WARN floor
  expect-missing out "JNET-debug"

// Scenario 3: a crashing run. The system's stack trace is captured as a "jag
// decode ..." entry and the monitor must decode it back into a readable trace
// (mentioning the thrown message), with a non-zero exit marker.
scenario-crash jag/JagRunner fixtures/string -> none:
  jag.cleanup
  out := jag.run-monitored "$fixtures/crash.toit"
  expect-present out "JNET-CRASH"               // decoded exception message
  expect-present out "EXCEPTION"                // decoded trace header
  expect-missing out "jag decode"               // the raw entry was decoded, not passed through
  expect-present out "program stopped - exit code 1"
  expect-missing out "exit code 0"

// Scenario 5: two containers run in parallel with no filter; both streams must
// appear, and each container's own numbering must arrive complete and in order
// (interleaving between them is fine). Runs before scenario 4 so the buffer has
// no earlier ctrA/ctrB output to confuse the per-stream contiguity check.
scenario-interleave jag/JagRunner fixtures/string -> none:
  jag.cleanup
  // A roomy ring so nothing is evicted mid-window and every line is delivered.
  lines := jag.monitor-network --extra=["--log-buffer-size", "16384"] --duration=(Duration --s=4):
    jag.install "ctrA" "$fixtures/loop-a.toit"
    jag.install "ctrB" "$fixtures/loop-b.toit"
  jag.cleanup
  joined := lines.join "\n"
  // The device log buffer survives across runs, so the cursor-0 replay may show
  // stale ctrA/ctrB output from an earlier run before this run's fresh output.
  // Check the fresh run (the suffix that restarts numbering at 0) of each stream.
  check-from-zero (fresh-run (extract-indices joined "JNET-A:")) --stream="A"
  check-from-zero (fresh-run (extract-indices joined "JNET-B:")) --stream="B"

// Scenario 4: two containers run in parallel; a monitor filtered to ctrA must
// show ctrA's output and none of ctrB's. Exercises server-side name filtering
// (and the SIGINT detach path used to end the monitor window).
scenario-filter jag/JagRunner fixtures/string -> none:
  jag.cleanup
  lines := jag.monitor-network --containers=["ctrA"] --duration=(Duration --s=4):
    jag.install "ctrA" "$fixtures/loop-a.toit"
    jag.install "ctrB" "$fixtures/loop-b.toit"
  jag.cleanup
  joined := lines.join "\n"
  expect-present joined "JNET-A:"
  expect-missing joined "JNET-B:"

// Scenario 7: leave several short runs in the buffer, then a cursor-0 replay must
// show each run's exit marker separately (regression for collapsed markers).
// A small ring keeps the replay tiny (drains fast regardless of link speed) yet
// holds all the recent ticks; counting markers only from the last `runs` ticks
// ignores anything buffered by earlier scenarios.
scenario-replay jag/JagRunner fixtures/string -> none:
  jag.cleanup
  size := ["--log-buffer-size", "2048"]
  runs := 3
  runs.repeat: jag.run-monitored "$fixtures/tick.toit" --extra=size
  lines := jag.monitor-network --extra=size --duration=(Duration --s=4): null
  joined := lines.join "\n"
  ticks := all-indices-of joined "JNET-tick"
  check (ticks.size >= runs) "expected >= $runs tick runs in the replay, saw $ticks.size"
  // With the collapse bug the three trailing exits would merge into one marker.
  tail := joined[ticks[ticks.size - runs]..]
  check-eq runs (count-occurrences tail "program stopped") --what="replayed exit markers"

// Scenario 6: flood the log over a small ring with `run -m`. Regression for the
// fixed whole-buffer-encode OOM: the run must finish cleanly, the monitor must
// report no drops, and every numbered line must arrive exactly once and in order.
scenario-flood jag/JagRunner fixtures/string -> none:
  jag.cleanup
  out := jag.run-monitored "$fixtures/flood.toit" --extra=["--log-buffer-size", "32768"]
  expect-present out "program stopped - exit code 0"
  expect-missing out "dropped"
  check-sequence (extract-indices out "JNET-F:") 2000
