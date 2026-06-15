// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Assertion helpers for the network test harness.
//
// These intentionally do NOT use the `expect` package. An `expect` failure
// aborts the whole program (it is not catchable), which would stop the suite at
// the first failing scenario. Instead each helper throws a plain string, which
// the harness's `run-scenario` catches so one scenario can fail while the rest
// keep running and a summary is still printed.

check cond/bool msg/string -> none:
  if not cond: throw msg

check-eq expected/any actual/any --what/string="value" -> none:
  if expected != actual: throw "$what: expected <$expected> but was <$actual>"

expect-present text/string needle/string -> none:
  check (text.contains needle) "expected to find \"$needle\""

expect-missing text/string needle/string -> none:
  check (not (text.contains needle)) "expected NOT to find \"$needle\""

// Asserts $nums equals [0, 1, ..., n-1]: a non-empty, complete, in-order,
// gap- and dup-free capture of a stream that numbers from zero.
check-from-zero nums/List --stream/string -> none:
  check (nums.size > 0) "stream $stream: no lines captured"
  nums.size.repeat: check-eq it nums[it] --what="stream $stream index"

// Asserts $nums is exactly [0, 1, ..., n-1].
check-sequence nums/List n/int -> none:
  check-eq n nums.size --what="line count"
  n.repeat: check-eq it nums[it] --what="line $it"
