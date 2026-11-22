# RAW Import

Kleine macOS-App, die RAW-Fotos von der SD-Karte importiert und nach Aufnahmedatum sortiert.

## ⬇️ Download

### [**RAW Import für macOS herunterladen**](https://github.com/cheesycakeindustries/raw-import/releases/latest/download/RAW-Import.zip)

Läuft ab macOS 14 (Sonoma) auf Apple Silicon und Intel. [Alle Versionen](https://github.com/cheesycakeindustries/raw-import/releases)

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

1. **Herunterladen:** Klick oben auf [RAW Import für macOS herunterladen](https://github.com/cheesycakeindustries/raw-import/releases/latest/download/RAW-Import.zip). Die Datei `RAW-Import.zip` landet in deinem Ordner **Downloads**.
2. **Entpacken:** Doppelklick auf `RAW-Import.zip`. Daneben erscheint `RAW Import.app`. (Safari entpackt die Datei oft schon automatisch.)
3. **Installieren:** `RAW Import.app` in den Ordner **Programme** ziehen.
4. **Erster Start:** Die App ist nicht von Apple notarisiert, deshalb blockiert macOS sie beim ersten Öffnen. Das musst du nur einmal freigeben:
   1. `RAW Import` im Ordner Programme per Doppelklick öffnen. Es erscheint die Meldung *„RAW Import“ kann nicht geöffnet werden …*. Schließ sie mit **Fertig** bzw. **OK** (nicht mit „In den Papierkorb legen“).
   2. **Systemeinstellungen → Datenschutz & Sicherheit** öffnen und ganz nach unten scrollen.
   3. Bei *„RAW Import“ wurde blockiert …* auf **Dennoch öffnen** klicken und mit deinem Mac-Passwort oder Touch ID bestätigen.
   4. Die App startet. Ab jetzt öffnet sie sich ganz normal.

   <details>
   <summary>Alternative für Terminal-Nutzer</summary>

   ```bash
   xattr -dr com.apple.quarantine "/Applications/RAW Import.app"
   ```
   </details>

5. **SD-Karte erlauben:** Beim ersten Import fragt macOS, ob RAW Import auf Wechselmedien zugreifen darf. Klick auf **Erlauben**.

### Benutzung

1. SD-Karte einstecken, RAW Import öffnen und auf **Erkennen** klicken.
2. Unter **Ziel** den Ordner wählen, in dem `RAW/` angelegt werden soll, z. B. eine externe Festplatte.
3. Bei Bedarf jedem Tag ein Ereignis zuordnen (z. B. „Hochzeit“) und auf **Import starten** klicken.
4. Danach kannst du im Tab **SD-Karte aufräumen** die gesicherten Fotos von der Karte löschen.

### Update

Neue Version herunterladen und die alte `RAW Import.app` im Ordner Programme ersetzen.

### Deinstallieren

`RAW Import.app` aus dem Ordner Programme in den Papierkorb ziehen.

## Selbst bauen

Dafür brauchst du nur die Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh            # baut "RAW Import.app"
./release.sh 1.0      # baut und packt dist/RAW-Import-1.0.zip
```

Das App-Icon liegt in `icon/AppIcon.png`. Neu zeichnen lässt es sich mit `swift tools/make_icon.swift icon/AppIcon.png`.

## Lizenz

[MIT](LICENSE)
