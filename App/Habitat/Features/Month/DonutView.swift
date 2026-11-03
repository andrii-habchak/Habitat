import SwiftUI

/// An arc of a ring between two fractions of a turn (0 = 12 o'clock, clockwise).
struct DonutArcShape: Shape {
    let start: Double
    let end: Double
    /// Distance from the frame edge to the arc's centre line (half the stroke width).
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = max(min(rect.width, rect.height) / 2 - inset, 0)
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-90 + start * 360),
            endAngle: .degrees(-90 + end * 360),
            clockwise: false
        )
        return path
    }
}

/// A ring with one segment per habit in the habit's colour. Done = full colour and thick;
/// not done = dim and thin (so state is not colour alone). No segments: a faint empty ring.
struct DonutView: View {
    let segments: [DonutSegment]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let thick = size * 0.16
            let thin = thick * 0.45
            ZStack {
                if segments.isEmpty {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: thin)
                } else {
                    let arcs = DonutGeometry.arcs(count: segments.count)
                    ForEach(Array(zip(segments, arcs)), id: \.0.id) { segment, arc in
                        DonutArcShape(start: arc.start, end: arc.end, inset: thick / 2)
                            .stroke(
                                Color(hex: segment.colorHex).opacity(segment.isDone ? 1 : 0.3),
                                style: StrokeStyle(lineWidth: segment.isDone ? thick : thin)
                            )
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    DonutView(segments: [
        DonutSegment(habitID: UUID(), colorHex: "#E5484D", isDone: true),
        DonutSegment(habitID: UUID(), colorHex: "#30A46C", isDone: false),
        DonutSegment(habitID: UUID(), colorHex: "#3E63DD", isDone: true)
    ])
    .frame(width: 80)
}
