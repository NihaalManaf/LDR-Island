import AppKit

final class IslandWindowController: NSWindowController {
    private let configuration: AppConfiguration
    private let islandViewController: IslandViewController
    private var isExpanded: Bool
    private var collapseWorkItem: DispatchWorkItem?

    init(configuration: AppConfiguration) {
        self.configuration = configuration
        self.islandViewController = IslandViewController(configuration: configuration)
        self.isExpanded = configuration.startsExpanded

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

        islandViewController.setExpanded(isExpanded)
        applyWindowFrame(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        collapseWorkItem?.cancel()
    }

    func show() {
        applyWindowFrame(animated: false)
        window?.orderFrontRegardless()
    }

    @objc private func screenParametersChanged() {
        applyWindowFrame(animated: true)
    }

    private func handleHoverChanged(_ isHovering: Bool) {
        collapseWorkItem?.cancel()

        if isHovering {
            setExpanded(true, animated: true)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.setExpanded(false, animated: true)
        }

        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else {
            return
        }

        isExpanded = expanded
        islandViewController.setExpanded(expanded)
        applyWindowFrame(animated: animated)
    }

    private func applyWindowFrame(animated: Bool) {
        guard let window else {
            return
        }

        let metrics = ScreenLocator.preferredLayoutMetrics()
        islandViewController.updateLayoutMetrics(metrics)

        let targetSize = isExpanded
            ? islandViewController.preferredExpandedSize
            : islandViewController.preferredCollapsedSize

        let targetFrame = ScreenLocator.islandFrame(
            for: targetSize,
            gapCenterInWindow: metrics.gapCenterInWindow(expanded: isExpanded)
        )

        guard animated else {
            window.setFrame(targetFrame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }
}
