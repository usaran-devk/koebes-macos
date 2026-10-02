import AppKit

/// A small spinning ring indicator used while checking for or installing
/// updates, replacing the SwiftUI `IndeterminateRing` view so the UI can be
/// built with AppKit only.
final class IndeterminateRingView: NSView {
    /// The stroke color of the ring.
    var color: NSColor {
        didSet { ringLayer.strokeColor = color.cgColor }
    }

    private let lineWidth: CGFloat
    private let ringLayer = CAShapeLayer()

    init(color: NSColor, size: CGFloat, lineWidth: CGFloat) {
        self.color = color
        self.lineWidth = lineWidth
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
        setupLayer(size: size)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupLayer(size: CGFloat) {
        let bounds = CGRect(x: 0, y: 0, width: size, height: size)
        ringLayer.bounds = bounds
        ringLayer.position = CGPoint(x: size / 2, y: size / 2)

        let radius = (size - lineWidth) / 2
        let center = CGPoint(x: size / 2, y: size / 2)
        let path = CGMutablePath()
        // 70% arc (open ring), matching the SwiftUI `.trim(from: 0, to: 0.7)`:
        // starts at 3 o'clock and runs clockwise (layer y-axis points up).
        path.addArc(center: center, radius: radius, startAngle: 0, endAngle: -2 * .pi * 0.7, clockwise: true)
        ringLayer.path = path
        ringLayer.fillColor = nil
        ringLayer.strokeColor = color.cgColor
        ringLayer.lineWidth = lineWidth
        ringLayer.lineCap = .round

        layer?.addSublayer(ringLayer)

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        // Negative = clockwise in an unflipped layer, like SwiftUI's rotationEffect.
        rotation.toValue = -Double.pi * 2
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        ringLayer.add(rotation, forKey: "rotate")
    }
}
