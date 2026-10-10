import QtQuick
import Quickshell
import Quickshell.Io

// Läuft dauerhaft in omarchy-shell und ersetzt den alten Polling-Watcher:
// inotify auf ~/.local/state/omarchy/current meldet Theme- und Hintergrundwechsel
// (auch `omarchy theme bg next` ohne Theme-Wechsel). Beim Shell-Start = Login
// wird einmal synchronisiert. Ob sich wirklich etwas geändert hat, entscheidet
// das CLI – doppelte Auslöser (Hook + Service) sind daher harmlos.
Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string cli: home + "/.config/omarchy/plugins/raimo.rgb-sync/bin/omarchy-rgb"
  readonly property string currentDir: home + "/.local/state/omarchy/current"
  property bool pending: false

  function requestSync() { debounce.restart() }

  // Theme-Wechsel feuert mehrere Events kurz hintereinander – zusammenfassen
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

  Process {
    id: watcher
    running: true
    command: ["inotifywait", "-mq", "-e", "create,moved_to,close_write", "--format", "%f", root.currentDir]
    stdout: SplitParser {
      onRead: function (name) {
        if (name === "background" || name === "theme" || name === "theme.name") root.requestSync()
      }
    }
    onExited: restartWatcher.start()
  }

  Timer { id: restartWatcher; interval: 5000; onTriggered: watcher.running = true }

  Component.onCompleted: requestSync()
}
