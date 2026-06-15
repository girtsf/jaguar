// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Installed container for the container-filter scenario: prints a tokened,
// numbered line forever so the monitor can verify per-container name filtering.

main:
  i := 0
  while true:
    print "JNET-A:$i"
    i++
    sleep --ms=200
