import SwiftUI

/// A custom SwiftUI-drawn step-line chart of a history's running count over
/// relative time. Swift Charts needs iOS 16 and this package targets iOS 15, so
/// the plot is drawn with `Path`/shapes: x = seconds since the history's
/// `startedAt`, y = running count. Both axes are drawn and labeled with ticks
/// derived from the data itself — the y ticks span the actual count range (and
/// 0), the x ticks span 0…the last event's elapsed time. A step line traces the
/// count; a marker sits at each event, colored by delta sign (up-tick = the
/// counter's accent, down-tick = the coffee/subtract hue). The point mapping is
/// a pure function, so the geometry is testable without a view.
public struct CounterGraphChart: View {
    let history: CounterHistory
    /// The counter's dot color — used for the line and up-tick markers.
    let accent: Color

    public init(history: CounterHistory, accent: Color) {
        self.history = history
        self.accent = accent
    }

    // Gutters reserve room for the axis tick labels and titles around the plot.
    private static let leftGutter: CGFloat = 52
    private static let bottomGutter: CGFloat = 34
    private static let topInset: CGFloat = 12
    private static let rightInset: CGFloat = 16
    private static let downColor = CounterTheme.dotColor("coffee")
    private static let labelFont = Font.system(size: 9, weight: .medium, design: .monospaced)
    private static let titleFont = Font.system(size: 9, weight: .bold, design: .monospaced)

    public var body: some View {
        GeometryReader { geo in
            let rect = Self.plotRect(in: geo.size)
            let r = Self.plot(series: history.cumulativeSeries(), in: rect)
            ZStack(alignment: .topLeading) {
                axisLines(rect: rect)
                zeroBaseline(rect: rect, zeroY: r.zeroY, minCount: r.minCount)
                Self.stepPath(r.points)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                markers(points: r.points)
                yTickLabels(rect: rect, result: r)
                xTickLabels(rect: rect, maxTime: r.maxTime)
                axisTitles(rect: rect)
            }
        }
    }

    // MARK: - Layers

    private func axisLines(rect: CGRect) -> some View {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // y axis
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // x axis
        }
        .stroke(CounterTheme.lineStrong, lineWidth: 1)
    }

    // The zero line is only drawn as a separate dashed guide when 0 is *inside*
    // the range (the count went negative); otherwise the x axis already sits at 0.
    @ViewBuilder private func zeroBaseline(rect: CGRect, zeroY: CGFloat, minCount: Int) -> some View {
        if minCount < 0 {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: zeroY))
                p.addLine(to: CGPoint(x: rect.maxX, y: zeroY))
            }
            .stroke(CounterTheme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    private func markers(points: [CGPoint]) -> some View {
        ForEach(history.events.indices, id: \.self) { i in
            Circle()
                .fill(history.events[i].delta >= 0 ? accent : Self.downColor)
                .frame(width: 9, height: 9)
                .position(points[i + 1]) // index 0 is the synthetic (0,0) origin
        }
    }

    // Y ticks: the max count (top), the min count (bottom), and 0 when it is a
    // distinct interior value — all pulled from the data's own range.
    private func yTickLabels(rect: CGRect, result: PlotResult) -> some View {
        let values = Array(Set([result.maxCount, 0, result.minCount])).sorted(by: >)
        let span = max(1, result.maxCount - result.minCount)
        return ForEach(values, id: \.self) { value in
            let y = rect.maxY - rect.height * CGFloat(Double(value - result.minCount) / Double(span))
            Text("\(value)")
                .font(Self.labelFont)
                .foregroundColor(CounterTheme.inkMuted)
                .frame(width: Self.leftGutter - 22, alignment: .trailing)
                .position(x: 14 + (Self.leftGutter - 22) / 2, y: y)
        }
    }

    // X ticks: start (0:00), midpoint, and the last event's elapsed time —
    // scaled to the data's actual time span.
    private func xTickLabels(rect: CGRect, maxTime: TimeInterval) -> some View {
        HStack(spacing: 0) {
            Text(Self.relativeTime(0))
            Spacer(minLength: 0)
            Text(Self.relativeTime(maxTime / 2))
            Spacer(minLength: 0)
            Text(Self.relativeTime(maxTime))
        }
        .font(Self.labelFont)
        .foregroundColor(CounterTheme.inkMuted)
        .frame(width: rect.width)
        .position(x: rect.midX, y: rect.maxY + 11)
    }

    private func axisTitles(rect: CGRect) -> some View {
        ZStack {
            Text("COUNT")
                .font(Self.titleFont)
                .foregroundColor(CounterTheme.inkMuted)
                .tracking(0.8)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .position(x: 9, y: rect.midY)
            Text("TIME (M:SS)")
                .font(Self.titleFont)
                .foregroundColor(CounterTheme.inkMuted)
                .tracking(0.8)
                .position(x: rect.midX, y: rect.maxY + 26)
        }
    }

    // MARK: - Pure geometry

    /// The plot area within the gutters that hold the axis labels/titles.
    static func plotRect(in size: CGSize) -> CGRect {
        CGRect(x: leftGutter, y: topInset,
               width: max(1, size.width - leftGutter - rightInset),
               height: max(1, size.height - topInset - bottomGutter))
    }

    /// The result of mapping a series into a plot rect: the plotted points, the y
    /// of the zero line, and the data-derived domain the axes label against.
    struct PlotResult {
        let points: [CGPoint]
        let zeroY: CGFloat
        let minCount: Int
        let maxCount: Int
        let maxTime: TimeInterval
    }

    /// Pure mapping from the cumulative series to plotted points and the domain.
    /// The count domain always includes 0 so the baseline is on-chart, and a
    /// minimum time/count span avoids divide-by-zero for a flat or single point
    /// series. View-free, so it can be unit-tested.
    static func plot(series: [CumulativePoint], in rect: CGRect) -> PlotResult {
        let counts = series.map(\.count)
        let minCount = min(0, counts.min() ?? 0)
        let maxCount = max(0, counts.max() ?? 0)
        let countSpan = max(1, maxCount - minCount)
        let maxTime = max(1, series.map(\.time).max() ?? 1)

        func x(_ t: TimeInterval) -> CGFloat { rect.minX + rect.width * CGFloat(t / maxTime) }
        func y(_ c: Int) -> CGFloat {
            rect.maxY - rect.height * CGFloat(Double(c - minCount) / Double(countSpan))
        }
        let points = series.map { CGPoint(x: x($0.time), y: y($0.count)) }
        return PlotResult(points: points, zeroY: y(0), minCount: minCount, maxCount: maxCount, maxTime: maxTime)
    }

    /// A step line: hold the previous count until the next event's time, then
    /// jump to the new count — the shape of a discrete tally over time.
    static func stepPath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            var previous = first
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: previous.y))
                path.addLine(to: point)
                previous = point
            }
        }
    }

    /// Formats a relative offset as `mm:ss`, or `h:mm:ss` once it passes an hour.
    /// The single source of truth shared by the axis ticks and the event list, so
    /// they always read the same way.
    static func relativeTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
