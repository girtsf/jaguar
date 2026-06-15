// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Emits one line per output channel, each with a unique token, for the network
// log regression harness. A DEBUG-level logger is used on purpose so the debug
// line reaches the device's capture provider; whether it is then kept is
// decided by the log buffer's min-level floor (the thing under test), not by the
// application-side logger.

import log

main:
  logger := log.default.with-level log.DEBUG-LEVEL
  print "JNET-print"
  logger.debug "JNET-debug"
  logger.info  "JNET-info"
  logger.warn  "JNET-warn"
  logger.error "JNET-error"
