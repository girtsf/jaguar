// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Floods the log with many contiguous, numbered lines to exercise the paginated
// /log drain under buffer eviction. Regression for the fixed whole-buffer-encode
// OOM: this must complete without rebooting the device and without dropping or
// duplicating any line.

FLOOD-COUNT ::= 2000

main:
  FLOOD-COUNT.repeat: print "JNET-F:$it"
