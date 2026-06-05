import AppKit
import Foundation

enum LaunchHealthReporter {
    @MainActor
    static func write(_ stage: String) {
        guard let path = ProcessInfo.processInfo.environment["MD2_HEALTH_FILE"] else {
            return
        }

        let visibleWindows = NSApplication.shared.windows.filter { $0.isVisible }.count
        let line = "\(stage): windows=\(NSApplication.shared.windows.count) visible=\(visibleWindows)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
