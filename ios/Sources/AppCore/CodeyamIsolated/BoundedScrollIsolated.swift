import SwiftUI

// Isolation scaffold for BoundedScroll — codeyam renders this View standalone on the
// booted iOS simulator. CODEYAM_ISOLATE_COMPONENT=BoundedScroll selects this struct in
// CodeyamIsolationHost.swift; CODEYAM_ISOLATE_SCENARIO picks the scenario below.
//
// BoundedScroll has no visual identity of its own — it content-hugs its child up
// to whatever height the parent allows, then scrolls. The scenarios show both
// regimes: a short child that hugs, and a tall child bounded to a short frame so
// it scrolls.
struct BoundedScrollIsolated: View {
    let scenario: String

    var body: some View {
        ZStack(alignment: .top) {
            CounterTheme.panel.ignoresSafeArea()
            Group {
                switch scenario {
                case "Overflowing":
                    // Many rows against a short cap → the body scrolls within it.
                    BoundedScroll(maxHeight: 320) {
                        rows(count: 12)
                    }
                default:
                    // A few rows under a generous cap → the region hugs its content.
                    BoundedScroll(maxHeight: 600) {
                        rows(count: 3)
                    }
                }
            }
            .padding(20)
            .padding(.top, 60)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func rows(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<count, id: \.self) { i in
                Text("ROW \(i + 1)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CounterTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .overlay(Rectangle().stroke(CounterTheme.line, lineWidth: 1))
            }
        }
    }
}
