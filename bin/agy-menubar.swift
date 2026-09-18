import Cocoa
import Foundation

class MenubarApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⚡ Kotalar..."
        }

        buildMenu(payload: nil)
        updateQuota()

        // Her 15 saniyede bir otomatik güncelle
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.updateQuota()
        }
    }

    func updateQuota() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let pipe = Pipe()

            // agy-quota veya yerel script ara
            let scriptDir = Bundle.main.bundlePath
            let candidates = [
                "/Users/\(NSUserName())/.local/bin/agy-quota",
                NSString(string: "~/Documents/antigravity/optimistic-hawking/bin/agy-quota").expandingTildeInPath,
                "/usr/local/bin/agy-quota"
            ]

            var execPath = "/usr/bin/env"
            var args = ["agy-quota", "--json"]

            for c in candidates {
                if FileManager.default.fileExists(atPath: c) {
                    execPath = c
                    args = ["--json"]
                    break
                }
            }

            process.executableURL = URL(fileURLWithPath: execPath.hasPrefix("/") ? execPath : "/usr/bin/env")
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let quotaData = json["data"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.applyQuota(quotaData)
                    }
                }
            } catch {
                // Sessiz hata yönetimi
            }
        }
    }

    func applyQuota(_ data: [String: Any]) {
        var min5hPct: Double? = nil
        var min5hTimeStr = ""
        let now = Date()

        let groups = data["groups"] as? [[String: Any]] ?? []

        for g in groups {
            let buckets = g["buckets"] as? [[String: Any]] ?? []
            for b in buckets {
                let bId = (b["bucketId"] as? String ?? "").lowercased()
                let frac = b["remainingFraction"] as? Double ?? 1.0
                let pct = frac * 100.0

                if bId.contains("5h") {
                    if min5hPct == nil || pct < min5hPct! {
                        min5hPct = pct
                        if let resetStr = b["resetTime"] as? String {
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            var d = formatter.date(from: resetStr)
                            if d == nil {
                                formatter.formatOptions = [.withInternetDateTime]
                                d = formatter.date(from: resetStr)
                            }
                            if let dt = d {
                                let diffSec = max(0, Int(dt.timeIntervalSince(now)))
                                let h = diffSec / 3600
                                let m = (diffSec % 3600) / 60
                                min5hTimeStr = String(format: "%02d:%02d", h, m)
                            }
                        }
                    }
                }
            }
        }

        if let button = statusItem.button {
            if let p = min5hPct {
                if !min5hTimeStr.isEmpty {
                    button.title = String(format: "⚡ %%.1f%% (%@)", p, min5hTimeStr)
                } else {
                    button.title = String(format: "⚡ %%.1f%%", p)
                }
            } else {
                button.title = "⚡ Antigravity"
            }
        }

        buildMenu(payload: data)
    }

    func buildMenu(payload: [String: Any]?) {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "⚡ Antigravity Model Kotaları", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        if let data = payload, let groups = data["groups"] as? [[String: Any]] {
            for g in groups {
                let gName = g["displayName"] as? String ?? "Grup"
                let groupHeader = NSMenuItem(title: "▶ \(gName)", action: nil, keyEquivalent: "")
                groupHeader.isEnabled = false
                menu.addItem(groupHeader)

                let buckets = g["buckets"] as? [[String: Any]] ?? []
                for b in buckets {
                    let bName = b["displayName"] as? String ?? "Havuz"
                    let frac = b["remainingFraction"] as? Double ?? 1.0
                    let pct = String(format: "%%%.1f", frac * 100.0)

                    var remStr = ""
                    if let resetStr = b["resetTime"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime]
                        if let dt = formatter.date(from: resetStr) {
                            let diffSec = max(0, Int(dt.timeIntervalSince(Date())))
                            let h = diffSec / 3600
                            let m = (diffSec % 3600) / 60
                            remStr = " (⏱️ \(h) sa \(m) dk)"
                        }
                    }

                    let item = NSMenuItem(title: "   • \(bName): \(pct)\(remStr)", action: nil, keyEquivalent: "")
                    menu.addItem(item)
                }
                menu.addItem(NSMenuItem.separator())
            }
        } else {
            let loadingItem = NSMenuItem(title: "Kota bilgisi yükleniyor...", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            menu.addItem(loadingItem)
            menu.addItem(NSMenuItem.separator())
        }

        let refreshItem = NSMenuItem(title: "🔄 Şimdi Yenile", action: #selector(onRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let terminalItem = NSMenuItem(title: "💻 Terminalde Göster (agy-quota)", action: #selector(onOpenTerminal), keyEquivalent: "t")
        terminalItem.target = self
        menu.addItem(terminalItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "❌ Çıkış", action: #selector(onQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func onRefresh() {
        if let button = statusItem.button {
            button.title = "⚡ Yenileniyor..."
        }
        updateQuota()
    }

    @objc func onOpenTerminal() {
        let script = "tell application \"Terminal\" to do script \"agy-quota; exit\""
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    @objc func onQuit() {
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = MenubarApp()
app.delegate = delegate
app.run()
