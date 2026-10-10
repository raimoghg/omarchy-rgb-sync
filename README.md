# RGB Sync – Omarchy-Plugin

Passt die OpenRGB-Beleuchtung (Gehäuse, Maus, Tastatur) automatisch an das
Hintergrundbild oder das Theme an. Nachfolger von `omarchy-openrgb-wallpaper-sync`
aus der Zeit vor Omarchy Quattro.

## Bestandteile

| Datei | Aufgabe |
|---|---|
| `bin/omarchy-rgb` | CLI mit der ganzen Logik (Farbe berechnen, OpenRGB setzen, Zustand speichern) |
| `Service.qml` | läuft in `omarchy-shell`, reagiert per inotify auf Theme-/Hintergrundwechsel und synct beim Login |
| `Panel.qml` | Bar-Button (Punkt = aktuelle LED-Farbe) + Popup |
| `~/.config/omarchy/hooks/theme-set.d/40-openrgb-led-sync` | ruft `omarchy-rgb sync` beim Theme-Wechsel (auch ohne laufende Shell) |

Einstellungen: `~/.config/omarchy/rgb-sync.json` · Zustand: `~/.local/state/omarchy-rgb/state.json`

## Bedienung

- **Linksklick** auf das Bar-Icon öffnet das Panel: Quelle (Hintergrund / Theme / Fest),
  Themefarbe, Sättigung, Helligkeit, An/Aus, Neu anwenden
- **Rechtsklick** schaltet die LEDs an/aus

```bash
omarchy-rgb status | jq          # Einstellungen + Zustand
omarchy-rgb preview              # Farbe berechnen ohne anzuwenden
omarchy-rgb set source theme     # wallpaper | theme | fixed
omarchy-rgb set themeKey color4  # Schlüssel aus colors.toml, oder "keyboard" (keyboard.rgb)
omarchy-rgb set fixedColor '#00FFAA'
omarchy-rgb set brightness 0.6
omarchy-rgb off / on
omarchy-rgb sync --force
omarchy-rgb devices              # openrgb -l
```

## Geräte

In `rgb-sync.json` unter `devices`: `id` aus `openrgb -l`, `channelOrder` korrigiert
vertauschte Farbkanäle (das MSI-Mainboard braucht `RBG`), `zones` leer = ganzes Gerät.
Alle Geräte werden in **einem** `openrgb`-Aufruf gesetzt (~5 s, meist Gerätescan).
