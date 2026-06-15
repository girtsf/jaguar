// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Sibling of loop-a.toit: a second installed container whose output must NOT
// appear when the monitor filters on the other container.

main:
  i := 0
  while true:
    print "JNET-B:$i"
    i++
    sleep --ms=200
