//
//  MarqueeText.swift
//  keyDrop
//

import SwiftUI

private struct ContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MarqueeText: View {
    let text: String
    let maxChars: Int
    let font: Font

    private let charWidth: CGFloat = 7.2
    private let scrollSpeed: CGFloat = 40

    @State private var hovering = false
    @State private var contentWidth: CGFloat = 0

    private var containerWidth: CGFloat { charWidth * CGFloat(maxChars) }
    private var overflow: CGFloat { max(0, contentWidth - containerWidth) }

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentWidthKey.self, value: geo.size.width)
                }
            )
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .offset(x: hovering ? -overflow : 0)
            .animation(
                hovering
                    ? .easeOut(duration: max(0.4, Double(overflow / scrollSpeed)))
                    : .easeOut(duration: 0.2),
                value: hovering
            )
            .onPreferenceChange(ContentWidthKey.self) { contentWidth = $0 }
            .onHover { hovering = $0 }
            .help(text)
    }
}
