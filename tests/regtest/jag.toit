// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import encoding.json
import host.pipe
import io
import monitor

// Signal used to detach a long-running `jag monitor network`.
SIGINT ::= 2

// Sends $signal to $pid (a forked subprocess resource). Calls the subprocess.kill
// primitive directly so we don't depend on pkg-host's private pipe.kill_.
send-signal_ pid signal:
  #primitive.subprocess.kill

/**
Thin wrapper around the `jag` CLI for the network-logging regression harness.

All invocations target a single $device and force plain ASCII output
  (--force-plain) so the captured text is stable to parse.
*/
class JagRunner:
  bin/string
  device/string

  constructor .bin .device:

  device-args_ -> List: return ["-d", device]

  /**
  Runs $path on the device with `-m` (network monitoring) and returns jag's full
    stdout once the program exits. The program must terminate on its own; as a
    safety net $timeout is passed to the device (-D jag.timeout) so a fixture that
    fails to exit is stopped instead of hanging the run.
  */
  run-monitored path/string --extra/List=[] --timeout/Duration=(Duration --s=30) -> string:
    timeout-define := ["-D", "jag.timeout=$(timeout.in-s)s"]
    args := [bin, "run", "-m", "--force-plain"] + timeout-define + device-args_ + extra + [path]
    return pipe.backticks args

  /** Installs $path as a named container; it starts running immediately. */
  install name/string path/string -> none:
    code := pipe.run-program ([bin, "container", "install", name, path] + device-args_)
    if code != 0: throw "container install '$name' failed (exit $code)"

  /** Uninstalls a named container, ignoring errors (it may not exist). */
  uninstall name/string -> none:
    catch: pipe.run-program ([bin, "container", "uninstall", name] + device-args_)

  /**
  Uninstalls every container except Jaguar's own, isolating one scenario from the
    next. Best-effort: a failure to list (e.g. a transient device error) leaves
    the device untouched rather than aborting the scenario.

  Note this does not clear the device log buffer, which survives across runs;
    only a reboot does that.
  */
  cleanup -> none:
    output/string? := null
    catch: output = pipe.backticks ([bin, "container", "list"] + device-args_)
    if output == null: return
    // Each row is "<device> <image-id> <name>"; the name is the last field. Skip
    // the header and never touch Jaguar's own container.
    (output.split "\n").do: | line/string |
      name := last-field_ line
      if name != "" and name != "NAME" and name != "jaguar":
        uninstall name

  /**
  Runs `jag monitor network` for $duration, filtered to $containers (if any) and
    with any $extra flags (e.g. --log-buffer-size), invoking $during in parallel
    once the monitor has attached, and returns every captured output line.
  */
  monitor-network --containers/List=[] --extra/List=[] --duration/Duration [during] -> List:
    args := [bin, "monitor", "network", "--force-plain"] + device-args_ + extra
    containers.do: args.add-all ["--container", it]
    // fork takes the full argv; argv[0] is also the command to exec.
    proc := pipe.fork --create-stdout args[0] args
    lines := []
    drained := monitor.Latch
    task::
      reader := proc.stdout.in
      while line := reader.read-line: lines.add line
      drained.set true
    sleep --ms=800        // Let the monitor attach before we generate output.
    during.call
    sleep duration        // Collection window.
    send-signal_ proc.pid SIGINT
    proc.wait
    drained.get           // Wait for the reader to drain to EOF.
    return lines

// Returns the last whitespace-separated field of $line, or "" if there is none.
last-field_ line/string -> string:
  fields := (line.trim.split " ").filter: it != ""
  return fields.is-empty ? "" : fields.last

/**
Scans the network with `jag` CLI and returns the name of the sole
  visible Jaguar device.

Used when the harness is run without an explicit device. Throws if zero or more
  than one device is visible, since the harness can't guess which to drive.
*/
detect-sole-device bin/string -> string:
  out := pipe.backticks [bin, "scan", "--list", "--output", "json", "--timeout", "3s"]
  devices := (json.parse out).get "devices" --if-absent=: []
  if devices.is-empty:
    throw "no Jaguar device visible on the network; pass one explicitly, e.g. make regtest DEVICE=<name>"
  if devices.size > 1:
    names := (devices.map: it["name"]).join ", "
    throw "$devices.size devices visible ($names); pass one explicitly, e.g. make regtest DEVICE=<name>"
  return devices[0]["name"]
