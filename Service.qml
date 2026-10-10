import QtQuick
import Quickshell
import Quickshell.Io

// Runs inside omarchy-shell for the whole session. inotify on
// ~/.local/state/omarchy/current reports theme and background changes (including
// `omarchy theme bg next` without a theme change); the shell starting means a
// fresh login, so we sync once on load. The CLI decides whether anything actually
// changed, so duplicate triggers are cheap.
Item {
  id: root

  property var shell: null

  readonly property string cli: String(Qt.resolvedUrl("bin/omarchy-rgb")).replace(/^file:\/\//, "")
  readonly property string currentDir: Quickshell.env("HOME") + "/.local/state/omarchy/current"
  property bool pending: false
  property bool polling: false

  function requestSync() { debounce.restart() }

  // A theme switch fires several events in a row - coalesce them
  Timer {
    id: debounce
    interval: 800
    onTriggered: {
      if (syncProc.running) { root.pending = true; return }
      syncProc.running = true
    }
  }

  Process {
    id: syncProc
    command: [root.cli, "sync"]
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
  Timer { interval: 3000; repeat: true; running: root.polling; onTriggered: root.requestSync() }

  Component.onCompleted: requestSync()
}
