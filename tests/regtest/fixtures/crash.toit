// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Throws an uncaught exception so the system emits a stack trace. Jaguar
// captures the trace as a "jag decode ..." entry which the monitor decodes back
// into a readable stack mentioning this message.

main:
  throw "JNET-CRASH"
