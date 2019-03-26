//
//  Attributes.swift
//  CommonMark
//
//  Created by Chris Eidhof on 19.03.19.
//

import Cocoa

struct Attributes {
    var family: String
    var size: CGFloat
    var bold: Bool = false
    var italic: Bool = false
    var textColor: NSColor = .textColor
    var backgroundColor: NSColor = .textBackgroundColor
    var firstlineHeadIndent: CGFloat = 0
    var headIndent: CGFloat = 0
    var tabStops: [CGFloat]
    var alignment: NSTextAlignment = .left
    var lineHeightMultiple: CGFloat = 1
    
    mutating func setIndent(_ value: CGFloat) {
        firstlineHeadIndent = value
        headIndent = value
    }
    
    init(family: String, size: CGFloat) {
        self.family = family
        self.size = size
        self.tabStops = (1..<10).map { CGFloat($0) * 2 * size }
    }
    
    var font: NSFont {
        var fontDescriptor = NSFontDescriptor(name: family, size: size)
        var traits = NSFontDescriptor.SymbolicTraits()
        if bold { traits.formUnion(.bold) }
        if italic { traits.formUnion(.italic )}
        if !traits.isEmpty { fontDescriptor = fontDescriptor.withSymbolicTraits(traits) }
        let font = NSFont(descriptor: fontDescriptor, size: size)!
        return font
    }
    
    var paragraphStyle: NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = firstlineHeadIndent
        paragraphStyle.headIndent = headIndent
        paragraphStyle.tabStops = tabStops.map { NSTextTab(textAlignment: .left, location: $0) }
        paragraphStyle.alignment = alignment
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        return paragraphStyle
    }
}

extension Attributes {
    var atts: [NSAttributedString.Key:Any] {
        return [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .backgroundColor: backgroundColor
        ]
    }
}
