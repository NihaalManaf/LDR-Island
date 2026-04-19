import AppKit

final class IslandWindowController: NSWindowController {
    private let configuration: AppConfiguration
    private let islandViewController: IslandViewController
    private var isExpanded: Bool
    private var usesExpandedWindowFrame: Bool
    private var collapseWorkItem: DispatchWorkItem?
    private var collapseFrameWorkItem: DispatchWorkItem?

    init(configuration: AppConfiguration) {
        self.configuration = configuration
        self.islandViewController = IslandViewController(configuration: configuration)
        self.isExpanded = configuration.startsExpanded
        self.usesExpandedWindowFrame = configuration.startsExpanded

        let panel = IslandPanel(contentViewController: islandViewController)
        super.init(window: panel)

        islandViewController.onHoverChanged = { [weak self] isHovering in
            self?.handleHoverChanged(isHovering)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        islandViewController.setWindowExpanded(usesExpandedWindowFrame)
        islandViewController.setExpanded(isExpanded)
        applyWindowFrame(expanded: usesExpandedWindowFrame, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        collapseWorkItem?.cancel()
        collapseFrameWorkItem?.cancel()
    }

    func show() {
        applyWindowFrame(expanded: usesExpandedWindowFrame, animated: false)
        window?.orderFrontRegardless()
    }

    @objc private func screenParametersChanged() {
        applyWindowFrame(expanded: usesExpandedWindowFrame, animated: true)
    }

    private func handleHoverChanged(_ isHovering: Bool) {
        collapseWorkItem?.cancel()

        if isHovering {
            setExpanded(true)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            if self.isMouseInsideWindow() {
                return
            }

            self.setExpanded(false)
        }

        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func setExpanded(_ expanded: Bool) {
        collapseFrameWorkItem?.cancel()

        guard expanded != isExpanded else {
            if expanded {
                usesExpandedWindowFrame = true
                islandViewController.setWindowExpanded(true)
                applyWindowFrame(expanded: true, animated: false)
            }
            return
        }

        isExpanded = expanded

        if expanded {
            usesExpandedWindowFrame = true
            islandViewController.setWindowExpanded(true)
            applyWindowFrame(
                expanded: true,
                animated: true,
                duration: islandViewController.openTransitionDuration,
                timingFunction: islandViewController.preferredOpenTimingFunction
            )
            islandViewController.setExpanded(true, animated: true)
            return
        }

        usesExpandedWindowFrame = false
        islandViewController.setWindowExpanded(false)
        applyWindowFrame(
            expanded: false,
            animated: true,
            duration: islandViewController.closeTransitionDuration,
            timingFunction: islandViewController.preferredCloseTimingFunction
        )
        islandViewController.setExpanded(false, animated: true)
    }

    private func isMouseInsideWindow() -> Bool {
        guard let window else {
            return false
        }

        let mouseLocation = NSEvent.mouseLocation
        return window.frame.contains(mouseLocation)
    }

    private func applyWindowFrame(
        expanded: Bool,
        animated: Bool,
        duration: TimeInterval = 0.18,
        timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    ) {
        guard let window else {
            return
        }

        let metrics = ScreenLocator.preferredLayoutMetrics()
        islandViewController.updateLayoutMetrics(metrics)

        let targetSize = expanded
            ? islandViewController.preferredExpandedSize
            : islandViewController.preferredCollapsedSize

        let targetFrame = ScreenLocator.islandFrame(
            for: targetSize,
            gapCenterInWindow: metrics.gapCenterInWindow(expanded: expanded)
        )

        guard animated else {
            window.setFrame(targetFrame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            window.animator().setFrame(targetFrame, display: true)
        }
    }
}
