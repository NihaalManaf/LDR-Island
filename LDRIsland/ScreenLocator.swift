import AppKit
import CoreGraphics

struct IslandLayoutMetrics: Equatable {
    let hasHardwareNotch: Bool
    let notchGapWidth: CGFloat
    let headerHeight: CGFloat
    let leadingBubbleWidth: CGFloat
    let trailingBubbleWidth: CGFloat
    let bodyWidth: CGFloat
    let bodyHeight: CGFloat
    let bodyTopSpacing: CGFloat

    var headerWidth: CGFloat {
        leadingBubbleWidth + notchGapWidth + trailingBubbleWidth
    }

    var gapCenterFromHeaderLeading: CGFloat {
        leadingBubbleWidth + notchGapWidth / 2
    }

    var headerCenterFromHeaderLeading: CGFloat {
        headerWidth / 2
    }

    var expandedLeftPadding: CGFloat {
        max(0, bodyWidth / 2 - headerCenterFromHeaderLeading)
    }

    var expandedRightPadding: CGFloat {
        max(0, bodyWidth / 2 - (headerWidth - headerCenterFromHeaderLeading))
    }

    var collapsedSize: NSSize {
        NSSize(width: headerWidth, height: headerHeight)
    }

    var expandedSize: NSSize {
        NSSize(
            width: headerWidth + expandedLeftPadding + expandedRightPadding,
            height: headerHeight + bodyTopSpacing + bodyHeight
        )
    }

    func gapCenterInWindow(expanded: Bool) -> CGFloat {
        let extra = expanded ? expandedLeftPadding : 0
        return extra + gapCenterFromHeaderLeading
    }
}

enum ScreenLocator {
    static func preferredScreen() -> NSScreen? {
        let screens = NSScreen.screens

        if let builtIn = screens.first(where: isBuiltInDisplay) {
            return builtIn
        }

        return NSScreen.main ?? screens.first
    }

    static func preferredLayoutMetrics() -> IslandLayoutMetrics {
        let gapWidth: CGFloat
        let headerHeight: CGFloat
        let hasHardwareNotch: Bool

        if let notch = notchDimensions(on: preferredScreen()) {
            gapWidth = notch.width
            headerHeight = notch.height + 6
            hasHardwareNotch = true
        } else {
            gapWidth = 0
            headerHeight = 38
            hasHardwareNotch = false
        }

        let leadingBubbleWidth: CGFloat = 148
        let trailingBubbleWidth: CGFloat = 64
        let closedHeaderWidth = leadingBubbleWidth + gapWidth + trailingBubbleWidth
        let notchExtensionInset: CGFloat = 12
        let bodyWidth = hasHardwareNotch
            ? max(320, closedHeaderWidth - notchExtensionInset)
            : max(404, closedHeaderWidth)

        return IslandLayoutMetrics(
            hasHardwareNotch: hasHardwareNotch,
            notchGapWidth: gapWidth,
            headerHeight: headerHeight,
            leadingBubbleWidth: leadingBubbleWidth,
            trailingBubbleWidth: trailingBubbleWidth,
            bodyWidth: bodyWidth,
            bodyHeight: 252,
            bodyTopSpacing: 0
        )
    }

    static func islandFrame(for size: NSSize, gapCenterInWindow: CGFloat, topMargin: CGFloat = 0) -> NSRect {
        guard let screen = preferredScreen() else {
            return NSRect(origin: .zero, size: size)
        }

        let anchorX = notchBounds(on: screen)?.midX ?? screen.frame.midX
        let x = anchorX - gapCenterInWindow
        let y = screen.frame.maxY - size.height - topMargin
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private static func notchBounds(on screen: NSScreen?) -> CGRect? {
        guard let screen, let notch = notchDimensions(on: screen) else {
            return nil
        }

        return CGRect(
            x: screen.frame.midX - notch.width / 2,
            y: screen.frame.maxY - notch.height,
            width: notch.width,
            height: notch.height
        )
    }

    private static func notchDimensions(on screen: NSScreen?) -> CGSize? {
        guard let screen, #available(macOS 12.0, *) else {
            return nil
        }

        let notchHeight = screen.safeAreaInsets.top
        guard notchHeight > 0 else {
            return nil
        }

        let leftPadding = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = screen.auxiliaryTopRightArea?.width ?? 0
        let notchWidth = screen.frame.width - leftPadding - rightPadding

        guard notchWidth > 0 else {
            return nil
        }

        return CGSize(width: notchWidth, height: notchHeight)
    }

    private static func isBuiltInDisplay(_ screen: NSScreen) -> Bool {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }

        return CGDisplayIsBuiltin(CGDirectDisplayID(screenNumber.uint32Value)) != 0
    }
}
