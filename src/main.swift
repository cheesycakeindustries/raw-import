import SwiftUI
import AppKit
import ImageIO

// MARK: - Konfiguration

let rawExtensions: Set<String> = [
    "arw", "srf", "sr2",          // Sony
    "raf",                        // Fujifilm
    "dng",                        // Adobe / Leica / Smartphones
    "nef", "nrw",                 // Nikon
    "cr2", "cr3", "crw",          // Canon
    "orf",                        // Olympus / OM System
    "rw2", "rwl",                 // Panasonic / Leica
    "pef",                        // Pentax
    "srw",                        // Samsung
    "3fr", "fff", "iiq", "x3f", "erf", "mos", "mrw", "kdc", "dcr"
]

/// Fotos bis 31.12.2026 -> "21.11.2026", ab 1.1.2027 -> "2027-01-01"
func folderName(for date: Date) -> String {
    let cal = Calendar(identifier: .gregorian)
    let year = cal.component(.year, from: date)
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE_POSIX")
    f.calendar = cal
    f.timeZone = .current
    f.dateFormat = year < 2027 ? "dd.MM.yyyy" : "yyyy-MM-dd"
    return f.string(from: date)
}

/// Aufnahmedatum aus EXIF, sonst Erstellungsdatum der Datei
func captureDate(of url: URL) -> Date {
    if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
       let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let candidates = [
            exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
            exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
            tiff?[kCGImagePropertyTIFFDateTime] as? String
        ]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        for c in candidates.compactMap({ $0 }) {
            if let d = f.date(from: c.trimmingCharacters(in: .whitespaces)) { return d }
        }
    }
    let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
    return values?.creationDate ?? values?.contentModificationDate ?? Date()
}

func fileSize(_ url: URL) -> Int64 {
    Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
}

func findRawFiles(in source: URL) -> [URL] {
    var files: [URL] = []
    if let en = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey],
                                               options: [.skipsHiddenFiles]) {
        for case let u as URL in en where rawExtensions.contains(u.pathExtension.lowercased()) {
            files.append(u)
        }
    }
    return files.sorted { $0.path < $1.path }
}

func yearDir(for date: Date, target: URL) -> URL {
    let year = Calendar(identifier: .gregorian).component(.year, from: date)
    return target.appendingPathComponent("RAW", isDirectory: true)
        .appendingPathComponent(String(year), isDirectory: true)
}

/// Ereignis für Ordnernamen bereinigen (keine / oder :)
func sanitizeEvent(_ s: String) -> String {
    s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Alle vorhandenen Ordner eines Tages: "21.11.2026" und "21.11.2026 <Ereignis>"
func existingDayFolders(for date: Date, target: URL) -> [URL] {
    let key = folderName(for: date)
    let dir = yearDir(for: date, target: target)
    let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                              options: [.skipsHiddenFiles])) ?? []
    return items.filter { u in
        let n = u.lastPathComponent
        let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDir && (n == key || n.hasPrefix(key + " "))
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
}

/// Ereignis aus einem vorhandenen Ordner des Tages (für Vorbelegung)
func existingEvent(for date: Date, target: URL?) -> String {
    guard let target else { return "" }
    let key = folderName(for: date)
    for f in existingDayFolders(for: date, target: target) {
        let n = f.lastPathComponent
        if n.count > key.count { return String(n.dropFirst(key.count + 1)) }
    }
    return ""
}

/// Zielordner: mit Ereignis "21.11.2026 Hochzeit", ohne Ereignis ein vorhandener Tagesordner oder "21.11.2026"
func dayFolder(for date: Date, event: String, target: URL) -> URL {
    let key = folderName(for: date)
    let ev = sanitizeEvent(event)
    let yd = yearDir(for: date, target: target)
    if !ev.isEmpty { return yd.appendingPathComponent(key + " " + ev, isDirectory: true) }
    return existingDayFolders(for: date, target: target).first ?? yd.appendingPathComponent(key, isDirectory: true)
}

/// Schon gesichert = in irgendeinem Ordner dieses Tages liegt die Datei mit gleicher Größe
func existingCopy(of file: URL, date: Date, target: URL) -> URL? {
    for d in existingDayFolders(for: date, target: target) {
        let c = d.appendingPathComponent(file.lastPathComponent)
        if FileManager.default.fileExists(atPath: c.path) && fileSize(c) == fileSize(file) { return c }
    }
    return nil
}

func isImported(_ file: URL, date: Date, target: URL?) -> Bool {
    guard let target else { return false }
    return existingCopy(of: file, date: date, target: target) != nil
}

/// Eine Datei importieren. Ergebnis: 0 kopiert, 1 übersprungen, 2 Fehler + Protokollzeile
func importOne(_ file: URL, date: Date, event: String, target: URL) -> (Int, String) {
    let fm = FileManager.default
    if let c = existingCopy(of: file, date: date, target: target) {
        return (1, "⏭  \(file.lastPathComponent) – schon in \(c.deletingLastPathComponent().lastPathComponent)")
    }
    let dayDir = dayFolder(for: date, event: event, target: target)
    let dest = dayDir.appendingPathComponent(file.lastPathComponent)
    do {
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) {
            return (2, "⚠️  \(file.lastPathComponent) – andere Datei mit gleichem Namen in \(dayDir.lastPathComponent), nicht überschrieben")
        }
        let tmp = dayDir.appendingPathComponent("." + file.lastPathComponent + ".part")
        try? fm.removeItem(at: tmp)
        try fm.copyItem(at: file, to: tmp)
        guard fileSize(tmp) == fileSize(file) else {
            try? fm.removeItem(at: tmp)
            return (2, "❌  \(file.lastPathComponent) – Größe stimmt nach dem Kopieren nicht")
        }
        try fm.moveItem(at: tmp, to: dest)
        return (0, "✅  \(file.lastPathComponent) → RAW/\(dayDir.deletingLastPathComponent().lastPathComponent)/\(dayDir.lastPathComponent)")
    } catch {
        return (2, "❌  \(file.lastPathComponent) – \(error.localizedDescription)")
    }
}

struct CardFile: Identifiable {
    let url: URL
    let date: Date
    let size: Int64
    let imported: Bool
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

func scanCard(source: URL, target: URL?) -> [CardFile] {
    findRawFiles(in: source).map { u in
        let d = captureDate(of: u)
        return CardFile(url: u, date: d, size: fileSize(u), imported: isImported(u, date: d, target: target))
    }
}

func formatBytes(_ b: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
}

func findSDCard() -> URL? {
    let keys: [URLResourceKey] = [.volumeIsRemovableKey, .volumeIsEjectableKey]
    let vols = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                     options: [.skipHiddenVolumes]) ?? []
    for v in vols {
        let dcim = v.appendingPathComponent("DCIM")
        if FileManager.default.fileExists(atPath: dcim.path) { return v }
    }
    return nil
}

// MARK: - Import-Logik

@MainActor
final class Importer: ObservableObject {
    @Published var source: URL? = findSDCard()
    @Published var target: URL? = UserDefaults.standard.url(forKey: "target")
    @Published var running = false
    @Published var total = 0
    @Published var done = 0
    @Published var copied = 0
    @Published var skipped = 0
    @Published var failed = 0
    @Published var status = "Bereit."
    @Published var log: [String] = []
    @Published var ejectWhenDone = UserDefaults.standard.bool(forKey: "eject")

    private var task: Task<Void, Never>?

    func chooseFolder(prompt: String) -> URL? {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = prompt
        return p.runModal() == .OK ? p.url : nil
    }

    func setTarget(_ url: URL) {
        target = url
        UserDefaults.standard.set(url, forKey: "target")
    }

    func cancel() { task?.cancel() }

    // MARK: SD-Karte aufräumen

    @Published var cardFiles: [CardFile] = []
    @Published var marked: Set<URL> = []
    @Published var cleanBusy = false
    @Published var confirmDelete = false
    @Published var cleanStatus = "Liste noch nicht geladen."

    /// Ereignis je Tag, Schlüssel = Datumsordnername ("21.11.2026")
    @Published var events: [String: String] = [:]

    struct Day: Identifiable { let key: String; let date: Date; let count: Int; var id: String { key } }
    var days: [Day] {
        var d: [String: (Date, Int)] = [:]
        for f in cardFiles { let k = folderName(for: f.date); d[k] = (d[k]?.0 ?? f.date, (d[k]?.1 ?? 0) + 1) }
        return d.map { Day(key: $0.key, date: $0.value.0, count: $0.value.1) }.sorted { $0.date < $1.date }
    }

    var markedFiles: [CardFile] { cardFiles.filter { marked.contains($0.url) } }

    func loadCard() {
        guard let source else { cardFiles = []; marked = []; cleanStatus = "Keine SD-Karte gewählt."; return }
        let target = self.target
        cleanBusy = true
        cleanStatus = "Lese SD-Karte …"
        Task.detached(priority: .userInitiated) { [self] in
            let files = scanCard(source: source, target: target)
            await MainActor.run {
                self.cardFiles = files
                // Ereignisse aus vorhandenen Ordnern vorbelegen, eigene Eingaben behalten
                for f in files {
                    let k = folderName(for: f.date)
                    if (self.events[k] ?? "").isEmpty { self.events[k] = existingEvent(for: f.date, target: target) }
                }
                self.marked = self.marked.intersection(files.map(\.url))
                let imp = files.filter(\.imported).count
                self.cleanStatus = "\(files.count) RAW-Dateien auf der Karte, davon \(imp) im Ziel gesichert."
                    + (target == nil ? " (Kein Ziel gewählt – Sicherung nicht prüfbar.)" : "")
                self.cleanBusy = false
            }
        }
    }

    func markAll() { marked = Set(cardFiles.map(\.url)) }
    func markImported() { marked = Set(cardFiles.filter(\.imported).map(\.url)) }
    func markNone() { marked = [] }

    func deleteMarked() {
        let urls = markedFiles.map(\.url)
        cleanBusy = true
        cleanStatus = "Lösche \(urls.count) Dateien …"
        Task.detached(priority: .userInitiated) { [self] in
            let fm = FileManager.default
            var ok = 0, failed = 0
            for u in urls {
                do {
                    try fm.removeItem(at: u)
                    ok += 1
                    // macOS-Begleitdatei auf FAT/exFAT-Karten mit entfernen
                    let ad = u.deletingLastPathComponent().appendingPathComponent("._" + u.lastPathComponent)
                    try? fm.removeItem(at: ad)
                } catch { failed += 1 }
            }
            let (ok2, failed2) = (ok, failed)
            await MainActor.run {
                let ok = ok2, failed = failed2
                self.marked = []
                self.log.append("🗑  \(ok) Dateien von der SD-Karte gelöscht" + (failed > 0 ? ", \(failed) Fehler" : "") + ".")
                self.cleanBusy = false
                self.loadCard()
            }
        }
    }

    func start() {
        guard let source, let target else { return }
        UserDefaults.standard.set(ejectWhenDone, forKey: "eject")
        running = true
        total = 0; done = 0; copied = 0; skipped = 0; failed = 0
        log = []
        status = "Suche RAW-Dateien …"
        let eject = ejectWhenDone
        let events = self.events

        task = Task.detached(priority: .userInitiated) { [self] in
            let files = findRawFiles(in: source)
            let count = files.count
            await MainActor.run { self.total = count; self.status = "\(count) RAW-Dateien gefunden." }

            for file in files {
                if Task.isCancelled { break }
                let date = captureDate(of: file)
                let (k0, line) = importOne(file, date: date, event: events[folderName(for: date)] ?? "", target: target)
                let l = line, k = k0
                await MainActor.run {
                    self.done += 1
                    switch k { case 0: self.copied += 1; case 1: self.skipped += 1; default: self.failed += 1 }
                    self.log.append(l)
                    self.status = "Datei \(self.done) von \(self.total)"
                }
            }

            let cancelled = Task.isCancelled
            await MainActor.run {
                self.running = false
                if cancelled {
                    self.status = "Abgebrochen – \(self.copied) kopiert, \(self.skipped) übersprungen."
                } else {
                    self.status = "Fertig: \(self.copied) kopiert, \(self.skipped) übersprungen, \(self.failed) Fehler."
                }
            }

            await MainActor.run { self.loadCard() }
            if eject && !cancelled {
                let ok = (try? NSWorkspace.shared.unmountAndEjectDevice(at: source)) != nil
                await MainActor.run {
                    self.log.append(ok ? "⏏️  SD-Karte ausgeworfen." : "⚠️  SD-Karte konnte nicht ausgeworfen werden.")
                    if ok { self.source = nil }
                }
            }
            if !cancelled {
                await MainActor.run { _ = NSSound(named: "Glass")?.play() }
            }
        }
    }
}

// MARK: - Oberfläche

struct ContentView: View {
    @StateObject private var imp = Importer()

    var body: some View {
        TabView {
            importView.tabItem { Text("Import") }
            CleanupView(imp: imp).tabItem { Text("SD-Karte aufräumen") }
        }
        .padding(12)
        .frame(minWidth: 700, minHeight: 640)
        .onAppear { imp.loadCard() }
    }

    var importView: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(title: "Quelle (SD-Karte)", url: imp.source, button: "Wählen …") {
                if let u = imp.chooseFolder(prompt: "Als Quelle verwenden") { imp.source = u; imp.loadCard() }
            } extra: {
                Button("Erkennen") { imp.source = findSDCard(); imp.loadCard() }
            }
            row(title: "Ziel (darin wird RAW/ angelegt)", url: imp.target, button: "Wählen …") {
                if let u = imp.chooseFolder(prompt: "Als Ziel verwenden") { imp.setTarget(u); imp.loadCard() }
            } extra: { EmptyView() }

            Text("Struktur: RAW/Jahr/Datum Ereignis – z. B. RAW/2026/21.11.2026 Hochzeit, ab 2027 als 2027-01-01 Hochzeit")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Text("Tage auf der Karte").font(.headline)
                Spacer()
                Button("Karte lesen") { imp.loadCard() }.disabled(imp.running || imp.cleanBusy || imp.source == nil)
            }
            if imp.days.isEmpty {
                Text(imp.cleanBusy ? "Lese SD-Karte …" : "Noch keine Fotos gelesen – „Karte lesen“ klicken.")
                    .foregroundStyle(.secondary).font(.callout)
            } else {
                List(imp.days) { d in
                    HStack {
                        Text(d.key).monospacedDigit().frame(width: 95, alignment: .leading)
                        Text("\(d.count) Fotos").foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 80, alignment: .leading)
                        TextField("Ereignis (optional), z. B. Hochzeit Anna", text: Binding(
                            get: { imp.events[d.key] ?? "" },
                            set: { imp.events[d.key] = $0 }))
                            .textFieldStyle(.roundedBorder)
                            .disabled(imp.running)
                    }
                }
                .frame(minHeight: 90, maxHeight: 170)
            }

            HStack {
                Toggle("SD-Karte danach auswerfen", isOn: $imp.ejectWhenDone)
                Spacer()
                if imp.running {
                    Button("Abbrechen") { imp.cancel() }
                } else {
                    Button("Import starten") { imp.start() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(imp.source == nil || imp.target == nil)
                }
            }

            ProgressView(value: Double(imp.done), total: Double(max(imp.total, 1)))
            HStack {
                Text(imp.status)
                Spacer()
                Text("✅ \(imp.copied)   ⏭ \(imp.skipped)   ❌ \(imp.failed)").monospacedDigit()
            }.font(.callout)

            ScrollViewReader { proxy in
                List(Array(imp.log.enumerated()), id: \.offset) { i, l in
                    Text(l).font(.system(.caption, design: .monospaced)).id(i)
                }
                .onChange(of: imp.log.count) { _, n in
                    if n > 0 { proxy.scrollTo(n - 1, anchor: .bottom) }
                }
            }
        }
        .padding(12)
    }

    @ViewBuilder
    func row<E: View>(title: String, url: URL?, button: String, action: @escaping () -> Void,
                      @ViewBuilder extra: () -> E) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            HStack {
                Text(url?.path ?? "– nicht gewählt –")
                    .foregroundStyle(url == nil ? .secondary : .primary)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                extra()
                Button(button, action: action).disabled(imp.running)
            }
        }
    }
}

struct CleanupView: View {
    @ObservedObject var imp: Importer

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy HH:mm"; return f
    }()

    var body: some View {
        let sel = imp.markedFiles
        let notSaved = sel.filter { !$0.imported }.count
        let selSize = sel.reduce(Int64(0)) { $0 + $1.size }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Karte: " + (imp.source?.path ?? "– keine –"))
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Liste neu laden") { imp.loadCard() }.disabled(imp.cleanBusy || imp.running)
            }
            HStack {
                Button("Alle") { imp.markAll() }
                Button("Nur gesicherte") { imp.markImported() }
                Button("Keine") { imp.markNone() }
                Spacer()
                Text("\(sel.count) von \(imp.cardFiles.count) ausgewählt · \(formatBytes(selSize))")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .disabled(imp.cleanBusy || imp.cardFiles.isEmpty)

            Table(imp.cardFiles) {
                TableColumn("") { f in
                    Toggle("", isOn: Binding(
                        get: { imp.marked.contains(f.url) },
                        set: { on in if on { imp.marked.insert(f.url) } else { imp.marked.remove(f.url) } }
                    )).labelsHidden()
                }.width(24)
                TableColumn("Datei") { f in Text(f.name) }
                TableColumn("Aufnahme") { f in Text(dateFmt.string(from: f.date)).monospacedDigit() }
                TableColumn("Größe") { f in Text(formatBytes(f.size)).monospacedDigit() }
                TableColumn("Im Ziel") { f in
                    Text(f.imported ? "✅ gesichert" : "⚠️ nicht gesichert")
                        .foregroundStyle(f.imported ? Color.primary : Color.orange)
                }
            }

            HStack {
                Text(imp.cleanStatus).font(.callout)
                Spacer()
                Button("Ausgewählte löschen …", role: .destructive) { imp.confirmDelete = true }
                    .disabled(sel.isEmpty || imp.cleanBusy || imp.running)
            }
        }
        .padding(12)
        .onAppear { if !imp.running { imp.loadCard() } }
        .alert("\(sel.count) RAW-Dateien endgültig löschen?", isPresented: $imp.confirmDelete) {
            Button("Endgültig löschen", role: .destructive) { imp.deleteMarked() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("\(formatBytes(selSize)) werden von der SD-Karte gelöscht. Das kann nicht rückgängig gemacht werden."
                 + (notSaved > 0 ? "\n\n⚠️ Achtung: \(notSaved) davon sind NICHT im Zielordner gesichert!" : ""))
        }
    }
}

@main
struct RAWImportApp: App {
    init() {
        // Testmodus: RAWImport --test-folder <datei>  gibt Zielordnernamen aus
        let a = CommandLine.arguments
        if a.count == 3, a[1] == "--test-folder" {
            let d = captureDate(of: URL(fileURLWithPath: a[2]))
            print(folderName(for: d)); exit(0)
        }
        // Testmodus: RAWImport --test-import <karte> <ziel> <Ereignis>
        if a.count == 5, a[1] == "--test-import" {
            for f in findRawFiles(in: URL(fileURLWithPath: a[2])) {
                print(importOne(f, date: captureDate(of: f), event: a[4], target: URL(fileURLWithPath: a[3])).1)
            }
            exit(0)
        }
        // Testmodus: RAWImport --test-scan <karte> <ziel>
        if a.count == 4, a[1] == "--test-scan" {
            for f in scanCard(source: URL(fileURLWithPath: a[2]), target: URL(fileURLWithPath: a[3])) {
                print(f.name, f.imported ? "gesichert" : "fehlt")
            }
            exit(0)
        }
    }
    var body: some Scene {
        WindowGroup("RAW Import") { ContentView() }
            .windowResizability(.contentMinSize)
    }
}
