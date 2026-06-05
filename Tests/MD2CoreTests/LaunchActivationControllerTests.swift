import AppKit
import MD2AppSupport
import Testing

@MainActor
struct LaunchActivationControllerTests {
    @Test func activateNowPromotesAppAndOrdersWindows() {
        let manager = FakeActivationManager(policy: .accessory)
        let controller = LaunchActivationController(manager: manager, scheduler: { _, _ in })

        controller.activateNow()

        #expect(manager.policyChanges == [.regular])
        #expect(manager.unhideCount == 1)
        #expect(manager.orderVisibleWindowsFrontCount == 1)
        #expect(manager.activateCount == 2)
    }

    @Test func activateNowDoesNotResetRegularPolicy() {
        let manager = FakeActivationManager(policy: .regular)
        let controller = LaunchActivationController(manager: manager, scheduler: { _, _ in })

        controller.activateNow()

        #expect(manager.policyChanges.isEmpty)
        #expect(manager.activateCount == 2)
    }

    @Test func activateAfterLaunchRetriesForLateSwiftUIWindows() {
        let manager = FakeActivationManager(policy: .prohibited)
        var scheduled: [(TimeInterval, @MainActor () -> Void)] = []
        let controller = LaunchActivationController(manager: manager) { delay, action in
            scheduled.append((delay, action))
        }

        controller.activateAfterLaunch()

        #expect(manager.activateCount == 2)
        #expect(scheduled.map(\.0) == LaunchActivationController.retryDelays)

        for item in scheduled {
            item.1()
        }

        #expect(manager.activateCount == 2 + (LaunchActivationController.retryDelays.count * 2))
        #expect(manager.orderVisibleWindowsFrontCount == 1 + LaunchActivationController.retryDelays.count)
    }

    @Test func activateAfterLaunchStopsRetryingOnceActive() {
        let manager = FakeActivationManager(policy: .regular)
        var scheduled: [(TimeInterval, @MainActor () -> Void)] = []
        let controller = LaunchActivationController(manager: manager) { delay, action in
            scheduled.append((delay, action))
        }

        controller.activateAfterLaunch()
        #expect(manager.activateCount == 2)

        // App is now frontmost; subsequent retries must not re-activate it or
        // they would steal focus back after the user switches to another app.
        manager.isActive = true

        for item in scheduled {
            item.1()
        }

        #expect(manager.activateCount == 2)
        #expect(manager.orderVisibleWindowsFrontCount == 1)
    }
}

@MainActor
private final class FakeActivationManager: AppActivationManaging {
    private(set) var activationPolicy: NSApplication.ActivationPolicy
    var isActive = false
    private(set) var policyChanges: [NSApplication.ActivationPolicy] = []
    private(set) var unhideCount = 0
    private(set) var orderVisibleWindowsFrontCount = 0
    private(set) var activateCount = 0

    init(policy: NSApplication.ActivationPolicy) {
        activationPolicy = policy
    }

    func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        activationPolicy = policy
        policyChanges.append(policy)
    }

    func unhide() {
        unhideCount += 1
    }

    func orderVisibleWindowsFront() {
        orderVisibleWindowsFrontCount += 1
    }

    func activateIgnoringOtherApps() {
        activateCount += 1
    }
}
