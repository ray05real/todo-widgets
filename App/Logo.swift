import SwiftUI

/// The app's logo, drawn the same way as the icon: "To Do" in a box with rounded corners, with one slit each in the
/// box, the T and the D (like Revolut's R). Units are the capital letters' height.
struct LogoShape: Shape {
    private let stroke = 0.18
    private let slit = 0.085
    private let xHeight = 0.72
    private let tWidth = 0.84
    private let oWidth = 0.74
    private let dWidth = 0.82
    private let kern = 0.06
    private let space = 0.34
    private let pad = 0.42
    /// The box's corner radius (with the same continuous curve iOS uses).
    private let corner = 0.6

    private var wordWidth: Double { tWidth + kern + oWidth + space + dWidth + kern + oWidth }

    func path(in rect: CGRect) -> Path {
        let x0 = -pad - stroke, y0 = -pad - stroke
        let x1 = wordWidth + pad + stroke, y1 = 1 + pad + stroke
        let k = min(rect.width / (x1 - x0), rect.height / (y1 - y0))
        let dx = rect.midX - (x0 + x1) / 2 * k
        let dy = rect.midY - (y0 + y1) / 2 * k
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: dx + x * k, y: dy + y * k) }
        func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
            CGRect(x: dx + x * k, y: dy + y * k, width: w * k, height: h * k)
        }
        let s = stroke
        var path = Path()

        // The box: a frame with iOS's rounded (continuous) corners, and one slit in the left side just below the
        // top corner. The path is filled even-odd, so the inner shape and the slit become gaps in the frame.
        path.addRoundedRect(in: r(x0, y0, x1 - x0, y1 - y0), cornerSize: CGSize(width: corner * k, height: corner * k),
                            style: .continuous)
        path.addRoundedRect(in: r(x0 + s, y0 + s, x1 - x0 - 2 * s, y1 - y0 - 2 * s),
                            cornerSize: CGSize(width: (corner - s) * k, height: (corner - s) * k), style: .continuous)
        path.addRect(r(x0, y0 + corner, s, slit))

        // T: the top bar, and the stem cut off below it.
        path.addRect(r(0, 0, tWidth, s))
        path.addRect(r(tWidth / 2 - s / 2, s + slit, s, 1 - s - slit))

        // o: rings on the baseline (filled even-odd, so the middle stays open).
        var x = tWidth + kern
        path.addEllipse(in: r(x, 1 - xHeight, oWidth, xHeight))
        path.addEllipse(in: r(x + s, 1 - xHeight + s, oWidth - 2 * s, xHeight - 2 * s))

        // D: one stroke from the top bar round the curve, along the bottom and up the stem, which stops short of
        // the top bar.
        x += oWidth + space
        let c = x + dWidth - 0.5
        path.move(to: p(x, 0))
        path.addLine(to: p(c, 0))
        path.addRelativeArc(center: p(c, 0.5), radius: 0.5 * k, startAngle: .degrees(-90), delta: .degrees(180))
        // (addLines would start a new piece; this has to carry on from the curve.)
        for point in [p(c, 1), p(x, 1), p(x, s + slit), p(x + s, s + slit), p(x + s, 1 - s), p(c, 1 - s)] {
            path.addLine(to: point)
        }
        path.addRelativeArc(center: p(c, 0.5), radius: (0.5 - s) * k, startAngle: .degrees(90), delta: .degrees(-180))
        path.addLine(to: p(x, s))
        path.closeSubpath()

        x += dWidth + kern
        path.addEllipse(in: r(x, 1 - xHeight, oWidth, xHeight))
        path.addEllipse(in: r(x + s, 1 - xHeight + s, oWidth - 2 * s, xHeight - 2 * s))
        return path
    }
}

/// The logo in white with a little shading, for the top of the first screen.
struct Logo: View {
    var body: some View {
        LogoShape()
            .fill(
                LinearGradient(colors: [.white, Color(white: 0.78)], startPoint: .top, endPoint: .bottom),
                style: FillStyle(eoFill: true)
            )
            .aspectRatio(4.8 / 2.2, contentMode: .fit)
            .accessibilityLabel("To Do")
    }
}
