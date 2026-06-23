import AlwaysOnlineCore
import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let idleReader = MacIdleTimeReader()
    private let mouseWiggler = QuartzMouseWiggler()
    private let controller = IdleWiggleController()
    private let idleThresholdKey = "idleThreshold"
    private let enabledKey = "isEnabled"
    private let wiggleDistanceKey = "wiggleDistance"
    private let accessibilityPromptInstallTokenKey = "accessibilityPromptInstallToken"

    private var timer: Timer?
    private var statusRefreshTimer: Timer?
    private var menu = NSMenu()
    private var settings = ActivitySettings.defaults
    private var lastKnownAccessibilityTrust: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = loadSettings()
        configureStatusItem()
        rebuildMenu()
        requestAccessibilityPermissionIfNeeded()
        startTimer()
        startStatusRefreshTimer()
        observeActivationNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        statusRefreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshAccessibilityState(force: true)
    }

    func menuDidClose(_ menu: NSMenu) {
        refreshAccessibilityState(force: true)
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        UserDefaults.standard.set(settings.isEnabled, forKey: enabledKey)
        controller.resetCooldown()
        updateStatusItem()
        rebuildMenu()
    }

    @objc private func setIdleThreshold(_ sender: NSMenuItem) {
        guard let threshold = sender.representedObject as? TimeInterval else {
            return
        }

        settings.idleThreshold = threshold
        UserDefaults.standard.set(threshold, forKey: idleThresholdKey)
        controller.resetCooldown()
        rebuildMenu()
    }

    @objc private func setWiggleDistance(_ sender: NSSlider) {
        // The slider snaps between discrete stops; its value is the stop index.
        let stops = ActivitySettings.wiggleDistanceStops
        let index = min(max(Int(sender.doubleValue.rounded()), 0), stops.count - 1)
        let distance = stops[index]
        settings.wiggleDistance = distance
        UserDefaults.standard.set(distance, forKey: wiggleDistanceKey)
        controller.resetCooldown()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func loadSettings() -> ActivitySettings {
        var loaded = ActivitySettings.defaults

        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            loaded.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }

        let savedThreshold = UserDefaults.standard.double(forKey: idleThresholdKey)
        if savedThreshold > 0 {
            loaded.idleThreshold = savedThreshold
        }

        let savedWiggleDistance = UserDefaults.standard.double(forKey: wiggleDistanceKey)
        if savedWiggleDistance > 0 {
            loaded.wiggleDistance = ActivitySettings.clampedWiggleDistance(savedWiggleDistance)
        }

        return loaded
    }

    private func configureStatusItem() {
        statusItem.length = NSStatusItem.squareLength
        updateStatusItem()
        statusItem.menu = menu
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.toolTip = "AlwaysOnline"
        button.title = StatusItemPresentation.title
        button.image = loadStatusIcon(
            resourceName: StatusItemPresentation.iconResourceName(
                isEnabled: isEffectivelyEnabled
            )
        )
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }

    private func rebuildMenu() {
        let nextMenu = NSMenu()
        nextMenu.delegate = self

        let titleItem = NSMenuItem(title: "AlwaysOnline", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        nextMenu.addItem(titleItem)

        let enabledItem = NSMenuItem(
            title: settings.isEnabled ? "Enabled" : "Disabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = settings.isEnabled ? .on : .off
        nextMenu.addItem(enabledItem)

        if let permissionMessage = StatusItemPresentation.permissionMessage(
            isAccessibilityTrusted: AccessibilityPermission.isTrusted
        ) {
            let permissionItem = NSMenuItem(
                title: permissionMessage,
                action: nil,
                keyEquivalent: ""
            )
            permissionItem.isEnabled = false
            nextMenu.addItem(permissionItem)
        }

        nextMenu.addItem(.separator())

        let thresholdItem = NSMenuItem(title: StatusItemPresentation.thresholdMenuTitle, action: nil, keyEquivalent: "")
        let thresholdMenu = NSMenu()
        addThresholdItem(to: thresholdMenu, value: 30)
        addThresholdItem(to: thresholdMenu, value: 60)
        addThresholdItem(to: thresholdMenu, value: 300)
        thresholdItem.submenu = thresholdMenu
        nextMenu.addItem(thresholdItem)

        addWiggleDistanceItem(to: nextMenu)

        nextMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        nextMenu.addItem(quitItem)

        menu = nextMenu
        statusItem.menu = menu
        updateStatusItem()
    }

    private func addThresholdItem(to menu: NSMenu, value: TimeInterval) {
        let title = StatusItemPresentation.thresholdPresetTitles[value] ?? "after \(Int(value)) seconds"
        let item = NSMenuItem(title: title, action: #selector(setIdleThreshold(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = value
        item.state = settings.idleThreshold == value ? .on : .off
        menu.addItem(item)
    }

    private func addWiggleDistanceItem(to menu: NSMenu) {
        let stops = ActivitySettings.wiggleDistanceStops
        let width: CGFloat = 340
        let textLeft: CGFloat = 23
        let contentRight: CGFloat = 24
        let trackWidth = width - textLeft - contentRight
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 62))

        let titleLabel = NSTextField(labelWithString: StatusItemPresentation.wiggleDistanceMenuTitle)
        titleLabel.font = .menuFont(ofSize: NSFont.systemFontSize)
        titleLabel.frame = NSRect(x: textLeft, y: 42, width: trackWidth, height: 20)
        view.addSubview(titleLabel)

        // Discrete slider that snaps between the preset stops; its value is the stop
        // index. The static scale labels below provide the read-out, so nothing needs
        // to repaint during the drag (which an NSMenu won't do for custom views).
        let slider = NSSlider(frame: NSRect(x: textLeft, y: 18, width: trackWidth, height: 20))
        slider.minValue = 0
        slider.maxValue = Double(stops.count - 1)
        slider.numberOfTickMarks = stops.count
        slider.allowsTickMarkValuesOnly = true
        slider.tickMarkPosition = .below
        slider.isContinuous = true
        slider.controlSize = .small
        let currentIndex = stops.firstIndex(of: ActivitySettings.nearestWiggleStop(settings.wiggleDistance)) ?? 0
        slider.doubleValue = Double(currentIndex)
        slider.target = self
        slider.action = #selector(setWiggleDistance(_:))
        slider.sendAction(on: [.leftMouseDragged, .leftMouseUp])
        view.addSubview(slider)

        // Static scale labels, centered under each tick.
        let knobInset = (slider.cell as? NSSliderCell)?.knobThickness ?? 11
        let usableWidth = trackWidth - knobInset
        for (index, stop) in stops.enumerated() {
            let label = NSTextField(labelWithString: String(Int(stop)))
            label.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            let labelWidth: CGFloat = 34
            let tickCenter = textLeft + knobInset / 2 + usableWidth * CGFloat(index) / CGFloat(stops.count - 1)
            var x = tickCenter - labelWidth / 2
            x = min(max(x, 0), width - labelWidth)
            label.frame = NSRect(x: x, y: 2, width: labelWidth, height: 13)
            view.addSubview(label)
        }

        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
    }

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer(
            timeInterval: settings.checkInterval,
            target: self,
            selector: #selector(timerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        timer?.tolerance = min(5, settings.checkInterval / 2)
    }

    private func startStatusRefreshTimer() {
        statusRefreshTimer?.invalidate()
        let newTimer = Timer(
            timeInterval: StatusItemPresentation.statusRefreshInterval,
            target: self,
            selector: #selector(statusRefreshTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(newTimer, forMode: .common)
        statusRefreshTimer = newTimer
        statusRefreshTimer?.tolerance = 0.25
    }

    private var isEffectivelyEnabled: Bool {
        settings.isEnabled && AccessibilityPermission.isTrusted
    }

    private func loadStatusIcon(resourceName: String) -> NSImage? {
        let image: NSImage?
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "png") {
            image = NSImage(contentsOf: url)
        } else if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            image = NSImage(contentsOf: url)
        } else {
            image = NSImage(
                systemSymbolName: "cursorarrow.motionlines",
                accessibilityDescription: "AlwaysOnline"
            )
        }

        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let currentInstallToken = currentAccessibilityPromptInstallToken()
        let lastPromptedInstallToken = UserDefaults.standard.string(
            forKey: accessibilityPromptInstallTokenKey
        )
        let isTrusted = AccessibilityPermission.isTrusted

        guard StatusItemPresentation.shouldRequestInitialAccessibilityPrompt(
            isAccessibilityTrusted: isTrusted,
            lastPromptedInstallToken: lastPromptedInstallToken,
            currentInstallToken: currentInstallToken
        ) else {
            if isTrusted && lastPromptedInstallToken != currentInstallToken {
                UserDefaults.standard.set(currentInstallToken, forKey: accessibilityPromptInstallTokenKey)
            }
            return
        }

        AccessibilityPermission.requestPrompt()
        UserDefaults.standard.set(currentInstallToken, forKey: accessibilityPromptInstallTokenKey)
        refreshAccessibilityState(force: true)
    }

    private func currentAccessibilityPromptInstallToken() -> String {
        StatusItemPresentation.accessibilityPromptInstallToken(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            bundlePath: Bundle.main.bundlePath
        )
    }

    private func observeActivationNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityRelatedStateMayHaveChanged(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(accessibilityRelatedStateMayHaveChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func accessibilityRelatedStateMayHaveChanged(_ notification: Notification) {
        refreshAccessibilityState(force: true)
    }

    @objc private func statusRefreshTimerFired(_ timer: Timer) {
        refreshAccessibilityState()
    }

    private func refreshAccessibilityState(force: Bool = false) {
        let isTrusted = AccessibilityPermission.isTrusted
        guard force || lastKnownAccessibilityTrust != isTrusted else {
            return
        }

        lastKnownAccessibilityTrust = isTrusted
        rebuildMenu()
    }

    @objc private func timerFired(_ timer: Timer) {
        runIdleCheck()
    }

    private func runIdleCheck() {
        refreshAccessibilityState()

        guard settings.isEnabled else {
            return
        }

        guard AccessibilityPermission.isTrusted else {
            return
        }

        let decision = controller.evaluate(
            idleDuration: idleReader.currentIdleDuration(),
            now: Date(),
            settings: settings
        )

        guard decision.shouldWiggle else {
            return
        }

        mouseWiggler.wiggle(
            distance: settings.wiggleDistance,
            repetitions: settings.wiggleRepetitions
        )
    }
}
