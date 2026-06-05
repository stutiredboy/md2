import AppKit
import Carbon
import Foundation

@MainActor
public protocol AppActivationManaging: AnyObject {
    var activationPolicy: NSApplication.ActivationPolicy { get }

    func setActivationPolicy(_ policy: NSApplication.ActivationPolicy)
    func unhide()
    func orderVisibleWindowsFront()
    func activateIgnoringOtherApps()
}

@MainActor
public final class NSApplicationActivationManager: AppActivationManaging {
    private let application: NSApplication

    public init(application: NSApplication = .shared) {
        self.application = application
    }

    public var activationPolicy: NSApplication.ActivationPolicy {
        application.activationPolicy()
    }

    public func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        application.setActivationPolicy(policy)
    }

    public func unhide() {
        application.unhide(nil)
    }

    public func orderVisibleWindowsFront() {
        for window in application.windows where window.isVisible {
            let originalLevel = window.level
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if window.level == .floating {
                    window.level = originalLevel
                }
            }
        }
    }

    public func activateIgnoringOtherApps() {
        var process = ProcessSerialNumber(
            highLongOfPSN: 0,
            lowLongOfPSN: UInt32(kCurrentProcess)
        )
        TransformProcessType(&process, UInt32(kProcessTransformToForegroundApplication))

        NSRunningApplication.current.activate(options: [
            .activateAllWindows,
            .activateIgnoringOtherApps
        ])
        application.activate(ignoringOtherApps: true)
    }
}

@MainActor
public struct LaunchActivationController {
    public typealias Scheduler = @MainActor (_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Void

    private let manager: AppActivationManaging
    private let scheduler: Scheduler

    public init(
        manager: AppActivationManaging = NSApplicationActivationManager(),
        scheduler: @escaping Scheduler = LaunchActivationController.defaultScheduler
    ) {
        self.manager = manager
        self.scheduler = scheduler
    }

    public func activateAfterLaunch() {
        activateNow()

        for delay in Self.retryDelays {
            scheduler(delay) {
                activateNow()
            }
        }
    }

    public func activateNow() {
        if manager.activationPolicy != .regular {
            manager.setActivationPolicy(.regular)
        }

        manager.unhide()
        manager.activateIgnoringOtherApps()
        manager.orderVisibleWindowsFront()
        manager.activateIgnoringOtherApps()
    }

    public static let retryDelays: [TimeInterval] = [0.15, 0.6, 1.2, 2.5, 5.0]

    public static func defaultScheduler(
        delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated {
                action()
            }
        }
    }
}
