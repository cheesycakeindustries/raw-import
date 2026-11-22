# RAW Import

Kleine macOS-App, die RAW-Fotos von der SD-Karte importiert und nach Aufnahmedatum sortiert.

## Funktionen

- **SD-Karte erkennen:** Findet die eingesteckte Karte automatisch, nämlich jedes Wechselmedium mit einem `DCIM`-Ordner.
- **Nach Tagen sortieren:** Liest das Aufnahmedatum aus den EXIF-Daten und legt diese Ordnerstruktur an:
  ```
  RAW/2026/21.11.2026 Hochzeit/
  RAW/2027/2027-01-01 Neujahr/
  ```
  Jedem Tag kannst du ein Ereignis zuordnen, also einen Namen für den Ordner.
- **Kein doppelter Import:** Dateien, die schon im Ziel liegen, werden übersprungen.
- **SD-Karte aufräumen:** Löscht bereits gesicherte Fotos von der Karte, nachdem du sie bestätigt hast.
- **Viele RAW-Formate:** Sony (ARW), Fujifilm (RAF), Canon (CR2/CR3), Nikon (NEF), DNG, Olympus/OM (ORF), Panasonic (RW2), Pentax (PEF) und weitere.

## Installation

1. Unter [Releases](../../releases) die neueste `RAW-Import-x.y.zip` herunterladen und entpacken.
2. `RAW Import.app` in den Ordner **Programme** ziehen.
3. **Beim ersten Start:** Die App ist nicht von Apple notarisiert, deshalb blockiert macOS sie zuerst.
   - App per Doppelklick öffnen. Es erscheint eine Warnung, die du mit **Fertig** bzw. **OK** schließt.
   - **Systemeinstellungen → Datenschutz & Sicherheit** öffnen, nach unten scrollen und bei „RAW Import“ auf **Dennoch öffnen** klicken.

   Alternativ geht es im Terminal:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/RAW Import.app"
   ```

**Voraussetzungen:** macOS 14 (Sonoma) oder neuer, Apple Silicon oder Intel.

## Selbst bauen

Dafür brauchst du nur die Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh            # baut "RAW Import.app"
./release.sh 1.0      # baut und packt dist/RAW-Import-1.0.zip
```

Das App-Icon liegt in `icon/AppIcon.png`. Neu zeichnen lässt es sich mit `swift tools/make_icon.swift icon/AppIcon.png`.

## Lizenz

[MIT](LICENSE)
