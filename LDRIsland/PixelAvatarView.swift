import AppKit

final class PixelAvatarView: NSView {
    private let avatarStyle: AvatarStyle
    private var isBlinking = false
    private var blinkTimer: Timer?

    init(style: AvatarStyle) {
        self.avatarStyle = style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        blinkTimer?.invalidate()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 34, height: 34)
    }

    override var isFlipped: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startAnimations()
        } else {
            stopAnimations()
        }
    }

    private func startAnimations() {
        layer?.removeAnimation(forKey: "bob")
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = -1.4
        bob.toValue = 1.4
        bob.duration = 1.35
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(bob, forKey: "bob")

        scheduleBlink()
    }

    private func stopAnimations() {
        layer?.removeAllAnimations()
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    private func scheduleBlink() {
        blinkTimer?.invalidate()
        let delay = Double.random(in: 2.6...5.2)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.performBlink()
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func performBlink() {
        isBlinking = true
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            guard let self else { return }
            self.isBlinking = false
            self.needsDisplay = true
            self.scheduleBlink()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let pattern = currentPattern()
        let rows = pattern.count
        let columns = pattern.first?.count ?? 1
        let pixelSize = floor(min(bounds.width / CGFloat(columns), bounds.height / CGFloat(rows)))
        let width = CGFloat(columns) * pixelSize
        let height = CGFloat(rows) * pixelSize
        let originX = floor((bounds.width - width) / 2)
        let originY = floor((bounds.height - height) / 2)

        for (rowIndex, row) in pattern.enumerated() {
            for (columnIndex, character) in row.enumerated() {
                guard let color = color(for: character) else {
                    continue
                }

                color.setFill()

                let rect = NSRect(
                    x: originX + (CGFloat(columnIndex) * pixelSize),
                    y: originY + (CGFloat(rowIndex) * pixelSize),
                    width: pixelSize,
                    height: pixelSize
                )

                NSBezierPath(rect: rect).fill()
            }
        }
    }

    private func currentPattern() -> [String] {
        switch avatarStyle {
        case .woman:
            return isBlinking ? womanPatternBlink : womanPattern
        case .man:
            return isBlinking ? manPatternBlink : manPattern
        }
    }

    private func color(for character: Character) -> NSColor? {
        switch character {
        case "H":
            return NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.14, alpha: 1)
        case "S":
            return NSColor(calibratedRed: 0.98, green: 0.84, blue: 0.73, alpha: 1)
        case "E":
            return NSColor(calibratedRed: 0.15, green: 0.10, blue: 0.09, alpha: 1)
        case "W":
            return NSColor.white
        case "R":
            return NSColor(calibratedRed: 1.00, green: 0.65, blue: 0.72, alpha: 1)
        case "M":
            return NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.45, alpha: 1)
        case "P":
            return NSColor(calibratedRed: 0.96, green: 0.52, blue: 0.70, alpha: 1)
        case "B":
            return NSColor(calibratedRed: 0.37, green: 0.61, blue: 0.95, alpha: 1)
        case "h":
            return NSColor(calibratedRed: 0.95, green: 0.80, blue: 0.35, alpha: 1)
        default:
            return nil
        }
    }

    private let womanPattern = [
        "....HHHHH....",
        "...HHHHHHH...",
        "..HHhhhhhHH..",
        ".HHhSSSSShHH.",
        ".HHSSSSSSSHH.",
        "HHSSEESEESSHH",
        "HHSSSSSSSSSHH",
        "HHSRSMMMSRSHH",
        ".HHSSSSSSSHH.",
        "..HHSSSSSHH..",
        "....PPPPP....",
        "...PPPPPPP...",
        "..PPPPPPPPP..",
        "..PPP...PPP..",
        "..PP.....PP.."
    ]

    private let womanPatternBlink = [
        "....HHHHH....",
        "...HHHHHHH...",
        "..HHhhhhhHH..",
        ".HHhSSSSShHH.",
        ".HHSSSSSSSHH.",
        "HHSSMMSMMSSHH",
        "HHSSSSSSSSSHH",
        "HHSRSMMMSRSHH",
        ".HHSSSSSSSHH.",
        "..HHSSSSSHH..",
        "....PPPPP....",
        "...PPPPPPP...",
        "..PPPPPPPPP..",
        "..PPP...PPP..",
        "..PP.....PP.."
    ]

    private let manPattern = [
        "...HH...",
        "..HSSH..",
        "..SSSS..",
        "..SSSS..",
        "...SS...",
        "..BBBB..",
        ".BBBBBB.",
        ".BB..BB."
    ]

    private let manPatternBlink = [
        "...HH...",
        "..HSSH..",
        "..MMMM..",
        "..SSSS..",
        "...SS...",
        "..BBBB..",
        ".BBBBBB.",
        ".BB..BB."
    ]
}
