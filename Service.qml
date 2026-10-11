import QtQuick
import Quickshell
import Quickshell.Io

// Runs inside omarchy-shell for the whole session. inotify on
// ~/.local/state/omarchy/current reports theme and background changes (including
// `omarchy theme bg next` without a theme change); the shell starting means a
// fresh login, so we sync once on load - forced, because the hardware loses its
// colors on reboot while theme and background stay the same. Plugging an RGB
// device in or out (udev hidraw/usb events) re-detects devices, so new ones join
// the sync. Otherwise the CLI decides whether anything actually changed, so
// duplicate triggers are cheap.
Item {
  id: root

  property var shell: null

  readonly property string cli: String(Qt.resolvedUrl("bin/omarchy-rgb")).replace(/^file:\/\//, "")
  readonly property string currentDir: Quickshell.env("HOME") + "/.local/state/omarchy/current"
  property bool pending: false
  property bool polling: false
  property bool forceNext: true
  property bool detectNext: false

  function requestSync() { debounce.restart() }

  // A theme switch fires several events in a row - coalesce them
  Timer {
    id: debounce
    interval: 800
    onTriggered: {
      if (syncProc.running) { root.pending = true; return }
      syncProc.command = [root.cli, "sync"]
        .concat(root.forceNext ? ["--force"] : [])
        .concat(root.detectNext ? ["--detect"] : [])
      root.forceNext = false
      root.detectNext = false
      syncProc.running = true
    }
  }

  Process {
    id: syncProc
    onExited: if (root.pending) { root.pending = false; debounce.restart() }
  }

  // Without inotify-tools fall back to polling; the CLI returns in a few
  // milliseconds when nothing changed.
  Process {
    id: probe
    running: true
    command: ["sh", "-c", "command -v inotifywait"]
    onExited: function (exitCode) {
      if (exitCode === 0) watcher.running = true
      else root.polling = true
    }
  }

  Process {
    id: watcher
    command: ["inotifywait", "-mq", "-e", "create,moved_to,close_write", "--format", "%f", root.currentDir]
    stdout: SplitParser {
      onRead: function (name) {
        if (name === "background" || name === "theme" || name === "theme.name") root.requestSync()
      }
    }
    onExited: restartWatcher.start()
  }

  Timer { id: restartWatcher; interval: 5000; onTriggered: watcher.running = true }

  // A device connecting fires a burst of events and needs a moment before
  // OpenRGB can talk to it - wait for things to settle, then re-detect.
  Process {
    id: hotplug
    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=hidraw", "--subsystem-match=usb"]
    stdout: SplitParser {
      onRead: function (line) {
        if (/ (add|remove) /.test(line)) hotplugSettle.restart()
      }
    }
    onExited: restartHotplug.start()
  }

  Timer { id: hotplugSettle; interval: 3000; onTriggered: { root.detectNext = true; root.requestSync() } }
  Timer { id: restartHotplug; interval: 30000; onTriggered: hotplug.running = true }
  Timer { interval: 3000; repeat: true; running: root.polling; onTriggered: root.requestSync() }

  Component.onCompleted: requestSync()
}
