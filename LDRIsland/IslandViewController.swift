 import AppKit
import QuartzCore

final class IslandViewController: NSViewController {
    var onHoverChanged: ((Bool) -> Void)?

    private var configuration: AppConfiguration
    private let timeService: TimeConversionService
    private var clockTimer: Timer?
    private var layoutMetrics = ScreenLocator.preferredLayoutMetrics()
    private var isExpanded: Bool = false

    private let hoverView = HoverTrackingContainerView(frame: .zero)
    private let chromeView = IslandChromeView()
    private let headerContainer = NSView()
    private let gapSpacer = NSView()
    private let leadingBubble = AttachedBubbleView(corners: [.layerMinXMinYCorner, .layerMaxXMinYCorner])
    private let trailingBubble = AttachedBubbleView(corners: [.layerMinXMinYCorner, .layerMaxXMinYCorner])
    private let bodyMaskView = NSView()
    private let bodyPanel = NSView()

    private var headerWidthConstraint: NSLayoutConstraint?
    private var headerHeightConstraint: NSLayoutConstraint?
    private var headerLeadingConstraint: NSLayoutConstraint?
    private var leadingBubbleWidthConstraint: NSLayoutConstraint?
    private var trailingBubbleWidthConstraint: NSLayoutConstraint?
    private var gapWidthConstraint: NSLayoutConstraint?
    private var bodyWidthConstraint: NSLayoutConstraint?
    private var bodyHeightConstraint: NSLayoutConstraint?
    private var bodyTopConstraint: NSLayoutConstraint?
    private var bodyRevealWidthConstraint: NSLayoutConstraint?
    private var bodyRevealHeightConstraint: NSLayoutConstraint?

    private var isWindowExpanded: Bool = false
    private let openAnimationDuration: TimeInterval = 0.64
    private let closeAnimationDuration: TimeInterval = 0.56

    private var openTransitionTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.2, 0.88, 0.24, 1)
    }

    private var closeTransitionTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.22, 0.82, 0.24, 1)
    }

    private lazy var avatarView = PixelAvatarView(style: configuration.partner.avatar)
    private let partnerCaptionLabel = IslandViewController.makeLabel(fontSize: 10, weight: .bold, color: .secondaryLabelColor)
    private let partnerTimeLabel = IslandViewController.makeMonospacedLabel(fontSize: 18, weight: .semibold)
    private let compactPartnerZoneLabel = IslandViewController.makeLabel(fontSize: 11, weight: .semibold, color: .secondaryLabelColor)
    private let partnerMetaLabel = IslandViewController.makeLabel(fontSize: 11, weight: .medium, color: .secondaryLabelColor)
    private let offsetLabel = IslandViewController.makeLabel(fontSize: 11, weight: .bold, color: .systemBlue)

    private let localConverterCaptionLabel = IslandViewController.makeLabel(fontSize: 10, weight: .bold, color: .secondaryLabelColor)
    private let partnerConverterCaptionLabel = IslandViewController.makeLabel(fontSize: 10, weight: .bold, color: .secondaryLabelColor)
    private let localDragTimeLabel = IslandViewController.makeMonospacedLabel(fontSize: 28, weight: .bold)
    private let partnerDragTimeLabel = IslandViewController.makeMonospacedLabel(fontSize: 28, weight: .bold)
    private let conversionMetaLabel = IslandViewController.makeLabel(fontSize: 12, weight: .semibold, color: .secondaryLabelColor)
    private let reunionCountdownLabel = IslandViewController.makeLabel(fontSize: 12, weight: .semibold, color: .systemPink)
    private let timelineView = TimeScrubberView()
    private lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Settings")
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(openSettings)
        return button
    }()
    private lazy var settingsWindowController = SettingsWindowController.shared
    private var selectedLocalMinutesFromMidnight: Int?

    init(configuration: AppConfiguration, timeService: TimeConversionService = TimeConversionService()) {
        self.configuration = configuration
        self.timeService = timeService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        clockTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    var preferredCollapsedSize: NSSize {
        layoutMetrics.collapsedSize
    }

    var preferredExpandedSize: NSSize {
        layoutMetrics.expandedSize
    }

    var openTransitionDuration: TimeInterval {
        openAnimationDuration
    }

    var closeTransitionDuration: TimeInterval {
        closeAnimationDuration
    }

    var preferredOpenTimingFunction: CAMediaTimingFunction {
        openTransitionTimingFunction
    }

    var preferredCloseTimingFunction: CAMediaTimingFunction {
        closeTransitionTimingFunction
    }

    private var collapsedBodyRevealWidth: CGFloat {
        layoutMetrics.headerWidth
    }

    override func loadView() {
        hoverView.onHoverChanged = { [weak self] isHovering in
            self?.onHoverChanged?(isHovering)
        }
        hoverView.translatesAutoresizingMaskIntoConstraints = false
        hoverView.wantsLayer = true
        hoverView.layer?.backgroundColor = NSColor.clear.cgColor
        view = hoverView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: AppSettingsStore.didChangeNotification,
            object: nil
        )
        buildUI()
        updateLayoutMetrics(layoutMetrics)
        setWindowExpanded(configuration.startsExpanded)
        setExpanded(configuration.startsExpanded)
        startClockTimer()
        refreshAll(referenceDate: Date())
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateChromeGeometry()
    }

    func updateLayoutMetrics(_ metrics: IslandLayoutMetrics) {
        layoutMetrics = metrics
        headerWidthConstraint?.constant = metrics.headerWidth
        headerHeightConstraint?.constant = metrics.headerHeight
        leadingBubbleWidthConstraint?.constant = metrics.leadingBubbleWidth
        trailingBubbleWidthConstraint?.constant = metrics.trailingBubbleWidth
        gapWidthConstraint?.constant = metrics.notchGapWidth
        bodyWidthConstraint?.constant = metrics.bodyWidth
        bodyHeightConstraint?.constant = metrics.bodyHeight
        bodyTopConstraint?.constant = metrics.bodyTopSpacing
        bodyRevealWidthConstraint?.constant = isExpanded ? metrics.bodyWidth : collapsedBodyRevealWidth
        bodyRevealHeightConstraint?.constant = isExpanded ? metrics.bodyHeight : 0
        headerLeadingConstraint?.constant = isWindowExpanded ? metrics.expandedLeftPadding : 0
        view.layoutSubtreeIfNeeded()
        updateChromeGeometry()
    }

    func setWindowExpanded(_ expanded: Bool) {
        isWindowExpanded = expanded
    }

    func setExpanded(_ expanded: Bool, animated: Bool = false) {
        isExpanded = expanded

        let targetWidth = expanded ? layoutMetrics.bodyWidth : collapsedBodyRevealWidth
        let targetHeight = expanded ? layoutMetrics.bodyHeight : 0
        let targetAlpha: CGFloat = expanded ? 1 : 0
        let targetHeaderLeading = isWindowExpanded ? layoutMetrics.expandedLeftPadding : 0

        guard animated else {
            bodyMaskView.isHidden = !expanded
            bodyMaskView.alphaValue = targetAlpha
            bodyRevealWidthConstraint?.constant = targetWidth
            bodyRevealHeightConstraint?.constant = targetHeight
            headerLeadingConstraint?.constant = targetHeaderLeading
            view.layoutSubtreeIfNeeded()
            updateChromeGeometry()
            view.window?.invalidateShadow()
            return
        }

        if expanded {
            bodyMaskView.isHidden = false
            bodyMaskView.alphaValue = 0
            bodyRevealWidthConstraint?.constant = collapsedBodyRevealWidth
            bodyRevealHeightConstraint?.constant = 0
            view.layoutSubtreeIfNeeded()
            updateChromeGeometry()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = expanded ? openAnimationDuration : closeAnimationDuration
            context.timingFunction = expanded ? openTransitionTimingFunction : closeTransitionTimingFunction
            bodyRevealWidthConstraint?.animator().constant = targetWidth
            bodyRevealHeightConstraint?.animator().constant = targetHeight
            headerLeadingConstraint?.animator().constant = targetHeaderLeading
            bodyMaskView.animator().alphaValue = targetAlpha
            view.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            guard let self else {
                return
            }

            self.bodyMaskView.isHidden = !expanded
            self.updateChromeGeometry()
            self.view.window?.invalidateShadow()
        }
    }

    @objc private func conversionInputChanged() {
        refreshConversion(referenceDate: Date())
    }

    @objc private func settingsDidChange() {
        configuration = AppConfiguration.current
        avatarView.avatarStyle = configuration.partner.avatar
        refreshAll(referenceDate: Date())
    }

    @objc private func openSettings() {
        settingsWindowController.show(configuration: configuration)
    }

    private func startClockTimer() {
        clockTimer?.invalidate()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshAll(referenceDate: Date())
        }

        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func refreshAll(referenceDate: Date) {
        let snapshot = timeService.clockSnapshot(
            referenceDate: referenceDate,
            local: configuration.local,
            partner: configuration.partner
        )

        partnerCaptionLabel.stringValue = configuration.partner.name.uppercased()
        partnerTimeLabel.stringValue = snapshot.partner.timeText
        compactPartnerZoneLabel.stringValue = snapshot.partner.zoneText
        partnerMetaLabel.stringValue = "\(snapshot.partner.dayText) • \(snapshot.partner.zoneText)"
        offsetLabel.stringValue = snapshot.offsetText

        if selectedLocalMinutesFromMidnight == nil {
            let localCalendar = calendar(for: configuration.local.resolvedTimeZone)
            let components = localCalendar.dateComponents([.hour, .minute], from: referenceDate)
            selectedLocalMinutesFromMidnight = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }

        refreshConversion(referenceDate: referenceDate)
    }

    private func refreshConversion(referenceDate: Date) {
        let localMinutes = max(0, min(selectedLocalMinutesFromMidnight ?? 0, 23 * 60 + 59))
        let components = DateComponents(hour: localMinutes / 60, minute: localMinutes % 60)
        let result = timeService.convert(
            timeOfDay: components,
            direction: .localToPartner,
            referenceDate: referenceDate,
            local: configuration.local,
            partner: configuration.partner
        )

        localConverterCaptionLabel.stringValue = configuration.local.name.uppercased()
        partnerConverterCaptionLabel.stringValue = configuration.partner.name.uppercased()
        localDragTimeLabel.stringValue = formattedTime(
            for: components,
            referenceDate: referenceDate,
            timeZone: configuration.local.resolvedTimeZone
        )
        partnerDragTimeLabel.stringValue = result.targetTimeText
        let partnerPossessive = configuration.partner.name
        let relativeDayText: String
        switch result.shift {
        case .sameDay:
            relativeDayText = "\(partnerPossessive)'s time is the same day"
        case .nextDay:
            relativeDayText = "\(partnerPossessive)'s time is the next day"
        case .previousDay:
            relativeDayText = "\(partnerPossessive)'s time is the previous day"
        case .days(let offset) where offset > 0:
            relativeDayText = "\(partnerPossessive)'s time is \(offset) days later"
        case .days(let offset):
            relativeDayText = "\(partnerPossessive)'s time is \(abs(offset)) days earlier"
        }

        conversionMetaLabel.stringValue = "\(relativeDayText) • \(result.targetDayText) • \(result.targetZoneText)"
        reunionCountdownLabel.stringValue = reunionCountdownText(referenceDate: referenceDate)
        reunionCountdownLabel.isHidden = reunionCountdownLabel.stringValue.isEmpty
        timelineView.minutesFromMidnight = localMinutes
    }

    private func buildUI() {
        chromeView.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        bodyPanel.translatesAutoresizingMaskIntoConstraints = false
        gapSpacer.translatesAutoresizingMaskIntoConstraints = false
        bodyMaskView.translatesAutoresizingMaskIntoConstraints = false
        bodyMaskView.wantsLayer = true
        bodyMaskView.layer?.masksToBounds = true
        bodyMaskView.alphaValue = 0
        bodyMaskView.isHidden = true

        view.addSubview(chromeView)
        view.addSubview(headerContainer)
        view.addSubview(bodyMaskView)

        NSLayoutConstraint.activate([
            chromeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeView.topAnchor.constraint(equalTo: view.topAnchor),
            chromeView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        headerWidthConstraint = headerContainer.widthAnchor.constraint(equalToConstant: layoutMetrics.headerWidth)
        headerHeightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: layoutMetrics.headerHeight)
        bodyWidthConstraint = bodyPanel.widthAnchor.constraint(equalToConstant: layoutMetrics.bodyWidth)
        bodyHeightConstraint = bodyPanel.heightAnchor.constraint(equalToConstant: layoutMetrics.bodyHeight)
        bodyTopConstraint = bodyMaskView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: layoutMetrics.bodyTopSpacing)
        bodyRevealWidthConstraint = bodyMaskView.widthAnchor.constraint(equalToConstant: collapsedBodyRevealWidth)
        bodyRevealHeightConstraint = bodyMaskView.heightAnchor.constraint(equalToConstant: 0)

        headerLeadingConstraint = headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: view.topAnchor),
            headerLeadingConstraint!,
            headerWidthConstraint!,
            headerHeightConstraint!
        ])

        leadingBubble.translatesAutoresizingMaskIntoConstraints = false
        trailingBubble.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(leadingBubble)
        headerContainer.addSubview(gapSpacer)
        headerContainer.addSubview(trailingBubble)

        leadingBubbleWidthConstraint = leadingBubble.widthAnchor.constraint(equalToConstant: layoutMetrics.leadingBubbleWidth)
        trailingBubbleWidthConstraint = trailingBubble.widthAnchor.constraint(equalToConstant: layoutMetrics.trailingBubbleWidth)
        gapWidthConstraint = gapSpacer.widthAnchor.constraint(equalToConstant: layoutMetrics.notchGapWidth)

        NSLayoutConstraint.activate([
            leadingBubble.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            leadingBubble.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            leadingBubble.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            leadingBubbleWidthConstraint!,

            gapSpacer.leadingAnchor.constraint(equalTo: leadingBubble.trailingAnchor),
            gapSpacer.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            gapSpacer.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            gapWidthConstraint!,

            trailingBubble.leadingAnchor.constraint(equalTo: gapSpacer.trailingAnchor),
            trailingBubble.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            trailingBubble.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            trailingBubble.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            trailingBubbleWidthConstraint!,

            bodyTopConstraint!,
            bodyMaskView.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            bodyRevealWidthConstraint!,
            bodyRevealHeightConstraint!
        ])

        bodyMaskView.addSubview(bodyPanel)

        NSLayoutConstraint.activate([
            bodyPanel.topAnchor.constraint(equalTo: bodyMaskView.topAnchor),
            bodyPanel.centerXAnchor.constraint(equalTo: bodyMaskView.centerXAnchor),
            bodyWidthConstraint!,
            bodyHeightConstraint!
        ])

        buildLeadingBubbleContent()
        buildTrailingBubbleContent()
        buildBodyPanelContent()
    }

    private func updateChromeGeometry() {
        chromeView.headerRect = headerContainer.frame
        chromeView.bodyRect = bodyMaskView.isHidden ? .zero : bodyMaskView.frame
    }

    private func buildLeadingBubbleContent() {
        partnerTimeLabel.alignment = .left
        compactPartnerZoneLabel.alignment = .left

        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6

        row.addArrangedSubview(partnerTimeLabel)
        row.addArrangedSubview(compactPartnerZoneLabel)
        leadingBubble.addSubview(row)

        compactPartnerZoneLabel.setContentHuggingPriority(.required, for: .horizontal)
        compactPartnerZoneLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        partnerTimeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingBubble.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(lessThanOrEqualTo: leadingBubble.trailingAnchor, constant: -12),
            row.topAnchor.constraint(greaterThanOrEqualTo: leadingBubble.topAnchor, constant: 4),
            row.bottomAnchor.constraint(lessThanOrEqualTo: leadingBubble.bottomAnchor, constant: -4),
            row.centerYAnchor.constraint(equalTo: leadingBubble.centerYAnchor)
        ])
    }

    private func buildTrailingBubbleContent() {
        trailingBubble.addSubview(avatarView)

        NSLayoutConstraint.activate([
            avatarView.centerXAnchor.constraint(equalTo: trailingBubble.centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: trailingBubble.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func buildBodyPanelContent() {
        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.spacing = 14
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 10, right: 16)

        bodyPanel.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: bodyPanel.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: bodyPanel.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: bodyPanel.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bodyPanel.bottomAnchor)
        ])

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.distribution = .fillEqually
        topRow.spacing = 18

        let localColumn = NSStackView()
        localColumn.orientation = .vertical
        localColumn.spacing = 8
        localDragTimeLabel.alignment = .left
        localColumn.addArrangedSubview(localConverterCaptionLabel)
        localColumn.addArrangedSubview(localDragTimeLabel)

        let partnerColumn = NSStackView()
        partnerColumn.orientation = .vertical
        partnerColumn.spacing = 8
        partnerDragTimeLabel.alignment = .right
        partnerConverterCaptionLabel.alignment = .right
        partnerColumn.addArrangedSubview(partnerConverterCaptionLabel)
        partnerColumn.addArrangedSubview(partnerDragTimeLabel)

        topRow.addArrangedSubview(localColumn)
        topRow.addArrangedSubview(partnerColumn)

        let arrowLabel = IslandViewController.makeLabel(fontSize: 15, weight: .bold, color: .secondaryLabelColor)
        arrowLabel.alignment = .center
        arrowLabel.stringValue = "YOUR TIME → HER TIME"

        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        timelineView.onMinutesChanged = { [weak self] minutes in
            self?.selectedLocalMinutesFromMidnight = minutes
            self?.refreshConversion(referenceDate: Date())
        }

        conversionMetaLabel.alignment = .center
        conversionMetaLabel.maximumNumberOfLines = 2
        conversionMetaLabel.lineBreakMode = .byWordWrapping
        reunionCountdownLabel.alignment = .left
        reunionCountdownLabel.maximumNumberOfLines = 1

        let footerRow = NSStackView()
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.distribution = .fill
        footerRow.spacing = 12
        footerRow.setContentHuggingPriority(.required, for: .vertical)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        reunionCountdownLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        settingsButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        footerRow.addArrangedSubview(reunionCountdownLabel)
        footerRow.addArrangedSubview(spacer)
        footerRow.addArrangedSubview(settingsButton)

        mainStack.addArrangedSubview(topRow)
        mainStack.addArrangedSubview(arrowLabel)
        mainStack.addArrangedSubview(timelineView)
        mainStack.addArrangedSubview(conversionMetaLabel)
        mainStack.addArrangedSubview(footerRow)
    }

    private func reunionCountdownText(referenceDate: Date) -> String {
        guard configuration.showsReunionCountdown, let reunionDate = configuration.reunionDate else {
            return ""
        }

        let start = Calendar.autoupdatingCurrent.startOfDay(for: referenceDate)
        let end = Calendar.autoupdatingCurrent.startOfDay(for: reunionDate)
        let days = Calendar.autoupdatingCurrent.dateComponents([.day], from: start, to: end).day ?? 0

        switch days {
        case ..<0:
            return "Reunion date passed"
        case 0:
            return "Seeing them today ♡"
        case 1:
            return "1 day until reunion ♡"
        default:
            return "\(days) days until reunion ♡"
        }
    }

    private func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func formattedTime(for components: DateComponents, referenceDate: Date, timeZone: TimeZone) -> String {
        let cal = calendar(for: timeZone)
        var day = cal.dateComponents([.year, .month, .day], from: referenceDate)
        day.hour = components.hour
        day.minute = components.minute
        day.second = 0
        let date = cal.date(from: day) ?? referenceDate

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private static func makeLabel(fontSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    private static func makeMonospacedLabel(fontSize: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let settingsViewController = SettingsWindowContentViewController()

    init() {
        let window = NSWindow(contentViewController: settingsViewController)
        window.title = "LDR Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titleVisibility = .visible
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 460, height: 360))
        window.setFrameAutosaveName("LDRSettingsWindow")
        super.init(window: window)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: AppSettingsStore.didChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show(configuration: AppConfiguration) {
        settingsViewController.apply(configuration: configuration)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func settingsDidChange() {
        settingsViewController.apply(configuration: AppConfiguration.current)
    }
}

final class SettingsWindowContentViewController: NSViewController {
    private let tabView = NSTabView()
    private let roleControl = NSPopUpButton()
    private let avatarControl = NSPopUpButton()
    private let localTimeZoneControl = NSPopUpButton()
    private let partnerTimeZoneControl = NSPopUpButton()
    private let showReunionToggle = NSButton(checkboxWithTitle: "Show reunion countdown in the notch extension", target: nil, action: nil)
    private let reunionPicker = NSDatePicker()
    private var didBuildUI = false

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        apply(configuration: AppConfiguration.current)
    }

    func apply(configuration: AppConfiguration) {
        guard didBuildUI else { return }

        roleControl.selectItem(withTitle: configuration.relationshipRole.displayName)
        avatarControl.selectItem(withTitle: configuration.partner.avatar.displayName)

        if let localID = configuration.local.timeZoneIdentifier {
            localTimeZoneControl.selectItem(withTitle: localID)
        } else {
            localTimeZoneControl.selectItem(at: 0)
        }

        partnerTimeZoneControl.selectItem(withTitle: configuration.partner.timeZoneIdentifier ?? "UTC")
        showReunionToggle.state = configuration.showsReunionCountdown ? .on : .off
        reunionPicker.dateValue = configuration.reunionDate ?? Date()
        updateReunionControls()
    }

    private func buildUI() {
        guard !didBuildUI else { return }
        didBuildUI = true

        let rootStack = NSStackView()
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.orientation = .vertical
        rootStack.spacing = 14
        rootStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.widthAnchor.constraint(equalToConstant: 460),
            view.heightAnchor.constraint(equalToConstant: 360)
        ])

        roleControl.addItems(withTitles: RelationshipRole.allCases.map(\.displayName))
        roleControl.target = self
        roleControl.action = #selector(roleChanged)

        avatarControl.addItems(withTitles: AvatarStyle.allCases.map(\.displayName))

        let timeZoneTitles = TimeZone.knownTimeZoneIdentifiers
        localTimeZoneControl.addItems(withTitles: ["Current System Time Zone"] + timeZoneTitles)
        partnerTimeZoneControl.addItems(withTitles: timeZoneTitles)

        reunionPicker.datePickerElements = [.yearMonthDay]
        reunionPicker.datePickerStyle = .textFieldAndStepper
        reunionPicker.datePickerMode = .single
        showReunionToggle.target = self
        showReunionToggle.action = #selector(reunionVisibilityChanged)

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder
        tabView.addTabViewItem(makePeopleTab())
        tabView.addTabViewItem(makeTimeZonesTab())
        tabView.addTabViewItem(makeReunionTab())

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let buttonRow = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        rootStack.addArrangedSubview(tabView)
        rootStack.addArrangedSubview(buttonRow)
        tabView.heightAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func makePeopleTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "people")
        item.label = "People"
        item.view = sectionView(
            title: "Relationship",
            subtitle: "Choose who you are and which partner avatar appears in the top-right corner.",
            rows: [
                labeledRow(title: "I am", control: roleControl),
                labeledRow(title: "Top-right avatar", control: avatarControl)
            ]
        )
        return item
    }

    private func makeTimeZonesTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "timeZones")
        item.label = "Time Zones"
        item.view = sectionView(
            title: "Time Zones",
            subtitle: "Pick your local time zone and your partner's time zone for the notch extension.",
            rows: [
                labeledRow(title: "My time zone", control: localTimeZoneControl),
                labeledRow(title: "Their time zone", control: partnerTimeZoneControl)
            ]
        )
        return item
    }

    private func makeReunionTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "reunion")
        item.label = "Reunion"
        item.view = sectionView(
            title: "Reunion Countdown",
            subtitle: "Show or hide the reunion countdown inside the expanded notch extension.",
            rows: [
                showReunionToggle,
                labeledRow(title: "Reunion date", control: reunionPicker)
            ]
        )
        return item
    }

    private func sectionView(title: String, subtitle: String, rows: [NSView]) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 14

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        rows.forEach { stack.addArrangedSubview($0) }

        return container
    }

    private func labeledRow(title: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, control])
        stack.orientation = .vertical
        stack.spacing = 6
        return stack
    }

    @objc private func roleChanged() {
        let role = RelationshipRole.allCases[max(0, roleControl.indexOfSelectedItem)]
        avatarControl.selectItem(withTitle: role.defaultPartnerAvatar.displayName)
    }

    @objc private func reunionVisibilityChanged() {
        updateReunionControls()
    }

    private func updateReunionControls() {
        reunionPicker.isEnabled = showReunionToggle.state == .on
        reunionPicker.alphaValue = reunionPicker.isEnabled ? 1 : 0.55
    }

    @objc private func cancel() {
        view.window?.close()
    }

    @objc private func saveSettings() {
        let role = RelationshipRole.allCases[max(0, roleControl.indexOfSelectedItem)]
        let localTimeZoneIdentifier = localTimeZoneControl.indexOfSelectedItem == 0 ? nil : localTimeZoneControl.titleOfSelectedItem
        let partnerTimeZoneIdentifier = partnerTimeZoneControl.titleOfSelectedItem
        let avatar = AvatarStyle.allCases[max(0, avatarControl.indexOfSelectedItem)]
        let showsReunionCountdown = showReunionToggle.state == .on
        let reunionDate = reunionPicker.dateValue

        AppSettingsStore.shared.update(
            relationshipRole: role,
            localTimeZoneIdentifier: localTimeZoneIdentifier,
            partnerTimeZoneIdentifier: partnerTimeZoneIdentifier,
            partnerAvatar: avatar,
            showsReunionCountdown: showsReunionCountdown,
            reunionDate: reunionDate
        )

        view.window?.close()
    }
}

final class HoverTrackingContainerView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let newTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
}

final class TimeScrubberView: NSControl {
    var onMinutesChanged: ((Int) -> Void)?

    var minutesFromMidnight: Int = 0 {
        didSet {
            minutesFromMidnight = max(0, min(minutesFromMidnight, 23 * 60 + 59))
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackRect = bounds.insetBy(dx: 6, dy: 12)
        let activeWidth = max(0, min(trackRect.width, trackRect.width * CGFloat(minutesFromMidnight) / CGFloat(23 * 60 + 59)))

        NSColor.white.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2).fill()

        let activeRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: activeWidth, height: trackRect.height)
        NSColor.systemPink.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: activeRect, xRadius: trackRect.height / 2, yRadius: trackRect.height / 2).fill()

        let knobX = trackRect.minX + activeWidth
        let knobRect = NSRect(x: knobX - 8, y: bounds.midY - 8, width: 16, height: 16)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knobRect).fill()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        update(with: convert(event.locationInWindow, from: nil).x)

        while let nextEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let localPoint = convert(nextEvent.locationInWindow, from: nil)
            update(with: localPoint.x)

            if nextEvent.type == .leftMouseUp {
                break
            }
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let step = event.modifierFlags.contains(.shift) ? 30 : 15
        let delta = event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY
        minutesFromMidnight += delta > 0 ? -step : step
        onMinutesChanged?(minutesFromMidnight)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123:
            minutesFromMidnight -= event.modifierFlags.contains(.shift) ? 30 : 15
            onMinutesChanged?(minutesFromMidnight)
        case 124:
            minutesFromMidnight += event.modifierFlags.contains(.shift) ? 30 : 15
            onMinutesChanged?(minutesFromMidnight)
        default:
            super.keyDown(with: event)
        }
    }

    private func update(with x: CGFloat) {
        let trackRect = bounds.insetBy(dx: 6, dy: 12)
        guard trackRect.width > 0 else { return }
        let progress = max(0, min(1, (x - trackRect.minX) / trackRect.width))
        minutesFromMidnight = Int(round(progress * CGFloat(23 * 60 + 59)))
        onMinutesChanged?(minutesFromMidnight)
    }
}

final class AttachedBubbleView: NSView {
    private let corners: CACornerMask

    init(corners: CACornerMask) {
        self.corners = corners
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        configureLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureLayer() {
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 14
        layer?.maskedCorners = corners
        layer?.borderWidth = 0
        layer?.borderColor = NSColor.clear.cgColor
    }
}

final class IslandChromeView: NSView {
    var headerRect: NSRect = .zero {
        didSet { updateShape() }
    }

    var bodyRect: NSRect = .zero {
        didSet { updateShape() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateShape()
    }

    private func updateShape() {
        let shapeLayer: CAShapeLayer

        if let existing = layer as? CAShapeLayer {
            shapeLayer = existing
        } else {
            shapeLayer = CAShapeLayer()
            layer = shapeLayer
        }

        let path = NSBezierPath.islandChrome(headerRect: headerRect, bodyRect: bodyRect)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.path = path?.cgPath
        shapeLayer.fillColor = NSColor.black.cgColor
        shapeLayer.strokeColor = NSColor.white.withAlphaComponent(0.08).cgColor
        shapeLayer.lineWidth = 1
        CATransaction.commit()
    }
}

private extension NSBezierPath {
    static func islandChrome(headerRect: NSRect, bodyRect: NSRect) -> NSBezierPath? {
        guard headerRect.width > 0, headerRect.height > 0 else {
            return nil
        }

        let closedBottomCornerRadius: CGFloat = 20

        guard bodyRect.width > 1, bodyRect.height > 1 else {
            return notchSurface(in: headerRect, topCornerRadius: 6, bottomCornerRadius: closedBottomCornerRadius)
        }

        let topR = min(CGFloat(6), headerRect.width / 4, headerRect.height / 4)

        if bodyRect.width <= headerRect.width + 0.5 {
            let closingRect = NSRect(
                x: headerRect.minX,
                y: min(bodyRect.minY, headerRect.minY),
                width: headerRect.width,
                height: headerRect.maxY - min(bodyRect.minY, headerRect.minY)
            )
            return notchSurface(in: closingRect, topCornerRadius: topR, bottomCornerRadius: closedBottomCornerRadius)
        }

        let bottomR = min(closedBottomCornerRadius, bodyRect.width / 4, bodyRect.height / 2)
        let shoulderDepth = min(CGFloat(12), max(CGFloat(6), (headerRect.height - topR) * 0.38))
        let leftCapEdgeX = headerRect.minX + topR
        let rightCapEdgeX = headerRect.maxX - topR
        let bodyTopY = bodyRect.maxY
        let path = NSBezierPath()

        path.move(to: NSPoint(x: headerRect.minX, y: headerRect.maxY))
        path.curve(
            to: NSPoint(x: leftCapEdgeX, y: headerRect.maxY - topR),
            controlPoint1: NSPoint(x: headerRect.minX + topR * 0.55, y: headerRect.maxY),
            controlPoint2: NSPoint(x: leftCapEdgeX, y: headerRect.maxY - topR * 0.55)
        )
        path.line(to: NSPoint(x: leftCapEdgeX, y: bodyTopY + shoulderDepth))
        path.curve(
            to: NSPoint(x: bodyRect.minX, y: bodyTopY),
            controlPoint1: NSPoint(x: leftCapEdgeX, y: bodyTopY + shoulderDepth * 0.3),
            controlPoint2: NSPoint(x: bodyRect.minX, y: bodyTopY + shoulderDepth * 0.2)
        )
        path.line(to: NSPoint(x: bodyRect.minX, y: bodyRect.minY + bottomR))
        path.curve(
            to: NSPoint(x: bodyRect.minX + bottomR, y: bodyRect.minY),
            controlPoint1: NSPoint(x: bodyRect.minX, y: bodyRect.minY + bottomR * 0.45),
            controlPoint2: NSPoint(x: bodyRect.minX + bottomR * 0.45, y: bodyRect.minY)
        )
        path.line(to: NSPoint(x: bodyRect.maxX - bottomR, y: bodyRect.minY))
        path.curve(
            to: NSPoint(x: bodyRect.maxX, y: bodyRect.minY + bottomR),
            controlPoint1: NSPoint(x: bodyRect.maxX - bottomR * 0.45, y: bodyRect.minY),
            controlPoint2: NSPoint(x: bodyRect.maxX, y: bodyRect.minY + bottomR * 0.45)
        )
        path.line(to: NSPoint(x: bodyRect.maxX, y: bodyTopY))
        path.curve(
            to: NSPoint(x: rightCapEdgeX, y: bodyTopY + shoulderDepth),
            controlPoint1: NSPoint(x: bodyRect.maxX, y: bodyTopY + shoulderDepth * 0.2),
            controlPoint2: NSPoint(x: rightCapEdgeX, y: bodyTopY + shoulderDepth * 0.3)
        )
        path.line(to: NSPoint(x: rightCapEdgeX, y: headerRect.maxY - topR))
        path.curve(
            to: NSPoint(x: headerRect.maxX, y: headerRect.maxY),
            controlPoint1: NSPoint(x: rightCapEdgeX, y: headerRect.maxY - topR * 0.55),
            controlPoint2: NSPoint(x: headerRect.maxX - topR * 0.55, y: headerRect.maxY)
        )
        path.close()
        return path
    }

    static func notchSurface(in rect: NSRect, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) -> NSBezierPath {
        let topR = min(topCornerRadius, rect.width / 4, rect.height / 4)
        let bottomR = min(bottomCornerRadius, rect.width / 4, rect.height / 2)
        let path = NSBezierPath()

        path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.curve(
            to: NSPoint(x: rect.minX + topR, y: rect.maxY - topR),
            controlPoint1: NSPoint(x: rect.minX + topR * 0.55, y: rect.maxY),
            controlPoint2: NSPoint(x: rect.minX + topR, y: rect.maxY - topR * 0.55)
        )
        path.line(to: NSPoint(x: rect.minX + topR, y: rect.minY + bottomR))
        path.curve(
            to: NSPoint(x: rect.minX + topR + bottomR, y: rect.minY),
            controlPoint1: NSPoint(x: rect.minX + topR, y: rect.minY + bottomR * 0.45),
            controlPoint2: NSPoint(x: rect.minX + topR + bottomR * 0.45, y: rect.minY)
        )
        path.line(to: NSPoint(x: rect.maxX - topR - bottomR, y: rect.minY))
        path.curve(
            to: NSPoint(x: rect.maxX - topR, y: rect.minY + bottomR),
            controlPoint1: NSPoint(x: rect.maxX - topR - bottomR * 0.45, y: rect.minY),
            controlPoint2: NSPoint(x: rect.maxX - topR, y: rect.minY + bottomR * 0.45)
        )
        path.line(to: NSPoint(x: rect.maxX - topR, y: rect.maxY - topR))
        path.curve(
            to: NSPoint(x: rect.maxX, y: rect.maxY),
            controlPoint1: NSPoint(x: rect.maxX - topR, y: rect.maxY - topR * 0.55),
            controlPoint2: NSPoint(x: rect.maxX - topR * 0.55, y: rect.maxY)
        )
        path.close()
        return path
    }

    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
