 import AppKit
import QuartzCore

final class IslandViewController: NSViewController {
    var onHoverChanged: ((Bool) -> Void)?

    private let configuration: AppConfiguration
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
    private let partnerTimeLabel = IslandViewController.makeMonospacedLabel(fontSize: 22, weight: .semibold)
    private let partnerMetaLabel = IslandViewController.makeLabel(fontSize: 11, weight: .medium, color: .secondaryLabelColor)
    private let offsetLabel = IslandViewController.makeLabel(fontSize: 11, weight: .bold, color: .systemBlue)

    private let localNowLabel = IslandViewController.makeMonospacedLabel(fontSize: 12, weight: .medium)
    private let partnerNowLabel = IslandViewController.makeMonospacedLabel(fontSize: 12, weight: .medium)
    private let conversionSummaryLabel = IslandViewController.makeMonospacedLabel(fontSize: 14, weight: .semibold)
    private let conversionDetailLabel = IslandViewController.makeLabel(fontSize: 11, weight: .medium, color: .secondaryLabelColor)
    private let converterTitleLabel = IslandViewController.makeLabel(fontSize: 10, weight: .bold, color: .secondaryLabelColor)

    private lazy var directionControl: NSSegmentedControl = {
        let control = NSSegmentedControl(labels: ["Mine → Hers", "Hers → Mine"], trackingMode: .selectOne, target: self, action: #selector(conversionInputChanged))
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegment = 0
        control.segmentStyle = .rounded
        return control
    }()

    private lazy var timePicker: NSDatePicker = {
        let picker = NSDatePicker()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.hourMinute]
        picker.datePickerMode = .single
        picker.timeZone = .autoupdatingCurrent
        picker.dateValue = Date()
        picker.target = self
        picker.action = #selector(conversionInputChanged)
        return picker
    }()

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
        min(layoutMetrics.bodyWidth, max(layoutMetrics.headerWidth, layoutMetrics.bodyWidth * 0.84))
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
        partnerMetaLabel.stringValue = "\(snapshot.partner.dayText) • \(snapshot.partner.zoneText)"
        offsetLabel.stringValue = snapshot.offsetText

        localNowLabel.stringValue = "\(snapshot.local.name): \(snapshot.local.timeText) • \(snapshot.local.dayText) • \(snapshot.local.zoneText)"
        partnerNowLabel.stringValue = "\(snapshot.partner.name): \(snapshot.partner.timeText) • \(snapshot.partner.dayText) • \(snapshot.partner.zoneText)"

        refreshConversion(referenceDate: referenceDate)
    }

    private func refreshConversion(referenceDate: Date) {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: timePicker.dateValue)
        let direction = ConversionDirection(rawValue: directionControl.selectedSegment) ?? .localToPartner
        let result = timeService.convert(
            timeOfDay: components,
            direction: direction,
            referenceDate: referenceDate,
            local: configuration.local,
            partner: configuration.partner
        )

        conversionSummaryLabel.stringValue = result.summaryText
        conversionDetailLabel.stringValue = result.detailText
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
        leadingBubble.addSubview(partnerTimeLabel)

        NSLayoutConstraint.activate([
            partnerTimeLabel.leadingAnchor.constraint(equalTo: leadingBubble.leadingAnchor, constant: 18),
            partnerTimeLabel.trailingAnchor.constraint(lessThanOrEqualTo: leadingBubble.trailingAnchor, constant: -14),
            partnerTimeLabel.topAnchor.constraint(greaterThanOrEqualTo: leadingBubble.topAnchor, constant: 4),
            partnerTimeLabel.bottomAnchor.constraint(lessThanOrEqualTo: leadingBubble.bottomAnchor, constant: -4),
            partnerTimeLabel.centerYAnchor.constraint(equalTo: leadingBubble.centerYAnchor)
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
        mainStack.spacing = 12
        mainStack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)

        bodyPanel.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: bodyPanel.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: bodyPanel.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: bodyPanel.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bodyPanel.bottomAnchor)
        ])

        let nowSection = NSStackView()
        nowSection.orientation = .vertical
        nowSection.spacing = 4

        let nowLabel = IslandViewController.makeLabel(fontSize: 10, weight: .bold, color: .secondaryLabelColor)
        nowLabel.stringValue = "NOW"

        nowSection.addArrangedSubview(nowLabel)
        nowSection.addArrangedSubview(localNowLabel)
        nowSection.addArrangedSubview(partnerNowLabel)

        let converterSection = NSStackView()
        converterSection.orientation = .vertical
        converterSection.spacing = 8

        converterTitleLabel.stringValue = "CONVERT"

        let inputRow = NSStackView()
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8

        timePicker.widthAnchor.constraint(greaterThanOrEqualToConstant: 116).isActive = true

        inputRow.addArrangedSubview(directionControl)
        inputRow.addArrangedSubview(timePicker)

        converterSection.addArrangedSubview(converterTitleLabel)
        converterSection.addArrangedSubview(inputRow)
        converterSection.addArrangedSubview(conversionSummaryLabel)
        converterSection.addArrangedSubview(conversionDetailLabel)

        mainStack.addArrangedSubview(nowSection)
        mainStack.addArrangedSubview(converterSection)
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

        guard bodyRect.width > 1, bodyRect.height > 1 else {
            return notchSurface(in: headerRect, topCornerRadius: 6, bottomCornerRadius: 20)
        }

        let topR = min(CGFloat(6), headerRect.width / 4, headerRect.height / 4)
        let bottomR = min(CGFloat(18), bodyRect.width / 4, bodyRect.height / 2)
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
