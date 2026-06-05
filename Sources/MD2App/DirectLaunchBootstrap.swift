import AppKit
import Darwin
import Foundation

enum DirectLaunchBootstrap {
    static func relaunchFromAppBundleIfNeeded() -> Bool {
        guard Bundle.main.bundleURL.pathExtension != "app",
              ProcessInfo.processInfo.environment["MD2_DISABLE_APP_BUNDLE_BOOTSTRAP"] != "1" else {
            return false
        }

        do {
            let executableURL = try currentExecutableURL()
            let bundleURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("MD2.app", isDirectory: true)

            try RuntimeAppBundleBuilder().build(
                bundleURL: bundleURL,
                executableURL: executableURL
            )

            try openBundle(bundleURL)
            return true
        } catch {
            fputs("MD2 could not start as a macOS app: \(error.localizedDescription)\n", stderr)
            return false
        }
    }

    private static func currentExecutableURL() throws -> URL {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        var size = UInt32(pathBuffer.count)

        if _NSGetExecutablePath(&pathBuffer, &size) != 0 {
            pathBuffer = [CChar](repeating: 0, count: Int(size))
            guard _NSGetExecutablePath(&pathBuffer, &size) == 0 else {
                throw BootstrapError.executablePathUnavailable
            }
        }

        let bytes = pathBuffer
            .prefix { $0 != 0 }
            .map { UInt8(bitPattern: $0) }
        let path = String(decoding: bytes, as: UTF8.self)

        return URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
    }

    private static func openBundle(_ bundleURL: URL) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.arguments = Array(CommandLine.arguments.dropFirst())
        var environment = ProcessInfo.processInfo.environment
        environment["MD2_DISABLE_APP_BUNDLE_BOOTSTRAP"] = "1"
        configuration.environment = environment

        let semaphore = DispatchSemaphore(value: 0)
        let launchResult = LaunchResult()

        NSWorkspace.shared.openApplication(
            at: bundleURL,
            configuration: configuration
        ) { _, error in
            launchResult.error = error
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 10) == .timedOut {
            throw BootstrapError.launchTimedOut
        }

        if let launchError = launchResult.error {
            throw launchError
        }
    }
}

private final class LaunchResult: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?

    var error: Error? {
        get {
            lock.withLock {
                storedError
            }
        }
        set {
            lock.withLock {
                storedError = newValue
            }
        }
    }
}

struct RuntimeAppBundleBuilder {
    func build(bundleURL: URL, executableURL: URL) throws {
        let fileManager = FileManager.default
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let bundledExecutableURL = macOSURL.appendingPathComponent("MD2")

        if fileManager.fileExists(atPath: bundleURL.path) {
            try fileManager.removeItem(at: bundleURL)
        }

        try fileManager.createDirectory(
            at: macOSURL,
            withIntermediateDirectories: true
        )

        try fileManager.copyItem(at: executableURL, to: bundledExecutableURL)

        let attributes = try fileManager.attributesOfItem(atPath: executableURL.path)
        if let permissions = attributes[.posixPermissions] {
            try fileManager.setAttributes(
                [.posixPermissions: permissions],
                ofItemAtPath: bundledExecutableURL.path
            )
        }

        try infoPlist.write(
            to: contentsURL.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )
    }

    private var infoPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>en</string>
            <key>CFBundleDocumentTypes</key>
            <array>
                <dict>
                    <key>CFBundleTypeExtensions</key>
                    <array>
                        <string>md</string>
                        <string>markdown</string>
                    </array>
                    <key>CFBundleTypeName</key>
                    <string>Markdown Document</string>
                    <key>CFBundleTypeRole</key>
                    <string>Editor</string>
                    <key>LSHandlerRank</key>
                    <string>Alternate</string>
                </dict>
            </array>
            <key>CFBundleExecutable</key>
            <string>MD2</string>
            <key>CFBundleIdentifier</key>
            <string>dev.codex.md2.debug</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>MD2</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>0.1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>LSMinimumSystemVersion</key>
            <string>14.0</string>
            <key>NSHighResolutionCapable</key>
            <true/>
        </dict>
        </plist>
        """
    }
}

enum BootstrapError: LocalizedError {
    case executablePathUnavailable
    case launchTimedOut

    var errorDescription: String? {
        switch self {
        case .executablePathUnavailable:
            "Could not resolve the running executable path."
        case .launchTimedOut:
            "Timed out while opening the MD2 app bundle."
        }
    }
}
