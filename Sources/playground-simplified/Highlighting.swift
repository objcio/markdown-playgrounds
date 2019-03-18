//
//  Highlighting.swift
//  CommonMark
//
//  Created by Chris Eidhof on 08.03.19.
//

import Foundation
import CommonMark
import Ccmark

extension String.UnicodeScalarView {
    var lineIndices: [String.Index] {
        var result = [startIndex]
        for i in indices {
            if self[i] == "\n" { // todo: should this be "\n" || "\r" ??
                result.append(self.index(after: i))
            }
        }
        return result
    }
}

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

let defaultAttributes = Attributes(family: "Helvetica", size: 18)
let accentColors: [NSColor] = [
    // From: https://ethanschoonover.com/solarized/#the-values
    (181, 137,   0),
    (203,  75,  22),
    (220,  50,  47),
    (211,  54, 130),
    (108, 113, 196),
    ( 38, 139, 210),
    ( 42, 161, 152),
    (133, 153,   0)
].map { NSColor(calibratedRed: CGFloat($0.0) / 255, green: CGFloat($0.1) / 255, blue: CGFloat($0.2) / 255, alpha: 1)}

struct CodeBlock {
    let range: NSRange
    let fenceInfo: String?
    let text: String
}

extension CommonMark.Node {
    /// When visiting a node, you can modify the state, and the modified state gets passed on to all children.
    func visitAll<State>(_ initial: State, _ callback: (Node, inout State) -> ()) {
        for c in children {
            var copy = initial
            callback(c, &copy)
            c.visitAll(copy, callback)
        }
    }
}

extension NSMutableAttributedString {
    var range: NSRange { return NSMakeRange(0, length) }
    
    func highlightMarkdown(_ swiftHighlighter: SwiftHighlighter) -> [CodeBlock] {
        setAttributes(defaultAttributes.atts, range: range)
        guard let parsed = Node(markdown: string) else { return [] }
        let scalars = string.unicodeScalars
        let lineNumbers = string.unicodeScalars.lineIndices
        func index(of pos: Position) -> String.Index {
            return string.index(lineNumbers[Int(pos.line-1)], offsetBy: Int(pos.column-1))
        }
        var result: [CodeBlock] = []
        parsed.visitAll(defaultAttributes) { el, attributes in
            guard el.start.column > 0 && el.start.line > 0 else { return }
            let start = index(of: el.start)
            let end = index(of: el.end)
            guard start <= end, start >= string.startIndex, end < string.endIndex else { return } // todo should be error?
            let range = start...end
            let nsRange = NSRange(range, in: string)
            
            switch el.type {
            case CMARK_NODE_HEADING:
                attributes.textColor = accentColors[1]
                attributes.size = defaultAttributes.size + 2 + (CGFloat(6-el.headerLevel)*1.7)
                addAttribute(.foregroundColor, value: attributes.textColor, range: nsRange)
                addAttribute(.font, value: attributes.font, range: nsRange)
            case CMARK_NODE_EMPH:
                attributes.italic = true
                addAttribute(.font, value: attributes.font, range: nsRange)
            case CMARK_NODE_STRONG:
                attributes.bold = true
                addAttribute(.font, value: attributes.font, range: nsRange)
            case CMARK_NODE_LINK:
                attributes.textColor = .linkColor
                addAttribute(.foregroundColor, value: attributes.textColor, range: nsRange)
                if let s = el.urlString, let u = URL(string: s) {
                    addAttribute(.link, value: u, range: nsRange)
                }
            case CMARK_NODE_CODE:
                attributes.family = "Monaco"
                addAttribute(.font, value: attributes.font, range: nsRange)
            case CMARK_NODE_BLOCK_QUOTE:
                attributes.family = "Georgia"
                attributes.setIndent(defaultAttributes.size)
                addAttribute(.font, value: attributes.font, range: nsRange)
                addAttribute(.paragraphStyle, value: attributes.paragraphStyle, range: nsRange)
            case CMARK_NODE_LIST:
                attributes.setIndent(defaultAttributes.size)
                addAttribute(.paragraphStyle, value: attributes.paragraphStyle, range: nsRange)
            case CMARK_NODE_CODE_BLOCK:
                addAttribute(.backgroundColor, value: NSColor.windowBackgroundColor, range: nsRange)
                addAttribute(.font, value: NSFont(name: "Monaco", size: attributes.size)!, range: nsRange)
                let block = CodeBlock(range: nsRange, fenceInfo: el.fenceInfo, text: el.literal!)
                if let res = swiftHighlighter.cache[el.literal!] {
                    highlightCodeBlock(block: block, result: res)
                }
                result.append(block)
            default:
                break
            }
        }
        return result
    }
}
