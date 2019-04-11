//
//  MarkdownHighlighting.swift
//  playground-simplified
//
//  Created by Florian Kugler on 19-03-2019.
//

import AppKit
import CommonMark
import Ccmark

extension NSMutableAttributedString {
    var range: NSRange { return NSMakeRange(0, length) }
    
    func highlightMarkdown() -> [CodeBlock] {
        guard let node = Node(markdown: string) else { return [] }
        
        let lineOffsets = string.lineOffsets
        var codeBlocks: [CodeBlock] = []
        
        func index(of pos: Position) -> String.Index {
            let lineStart = lineOffsets[Int(pos.line-1)]
            // We don't use endIndex but the index before, because we use it in a closed range
            let lastValidIndex = string.index(before: string.endIndex)
            return string.utf8.index(lineStart, offsetBy: Int(pos.column-1), limitedBy: lastValidIndex) ?? lastValidIndex
        }
        
        let defaultAttributes = Attributes(family: "Helvetica", size: 16)
        setAttributes(defaultAttributes.atts, range: range)
        
        node.visitAll(defaultAttributes) { c, attributes in
            guard c.start.line != 0 else { return } // CommonMark returns (0, 0) position for soft breaks
            let start = index(of: c.start)
            let end = index(of: c.end)
            guard start < end else { return }
            let nsRange = NSRange(start...end, in: string)
            switch c.type {
            case CMARK_NODE_HEADING:
                attributes.textColor = accentColors[1]
                attributes.size = defaultAttributes.size + 2 + (CGFloat(6-c.headerLevel)*1.7)
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
                if let s = c.urlString, let u = URL(string: s) {
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
                let code = c.literal!
                codeBlocks.append(CodeBlock(text: code, range: nsRange))
                if let tokens = try? code.highlightSwift() {
                    let offset = nsRange.location + (string[start...end] as NSString).range(of: code).location
                    for token in tokens {
                        var range = NSRange(token.range, in: code)
                        range.location += offset
                        addAttribute(.foregroundColor, value: token.kind.color, range: range)
                    }
                }
            default:
                break
            }
        }
        return codeBlocks
    }
}

struct Token {
    var range: Range<String.Index>
    var kind: Kind
    
    enum Kind {
        case keyword
        case string
        case number
    }
}

extension Token.Kind {
    var color: NSColor {
        switch self {
        case .keyword: return accentColors[4]
        case .string: return accentColors[2]
        case .number: return accentColors[3]
        }
    }
}

import SwiftSyntax

final class SwiftHighlighterRewriter: SyntaxRewriter {
    var tokens: [Token] = []
    let code: String
    
    init(code: String) {
        self.code = code
    }
    
    override func visit(_ token: TokenSyntax) -> Syntax {
        var range: Range<String.Index> {
            let start = code.utf8.index(code.utf8.startIndex, offsetBy: token.positionAfterSkippingLeadingTrivia.utf8Offset)
            let end = code.utf8.index(code.utf8.startIndex, offsetBy: token.endPosition.utf8Offset)
            return start..<end
        }
        switch token.tokenKind {
        case .stringSegment, .stringQuote, .stringLiteral:
            tokens.append(Token(range: range, kind: .string))
        case .integerLiteral, .floatingLiteral:
            tokens.append(Token(range: range, kind: .number))
        case let kind where kind.isKeyword:
            tokens.append(Token(range: range, kind: .keyword))
        default:
            ()
        }
        return token
    }
}

extension String {
    func highlightSwift() throws -> [Token] {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileName = "\(UUID().uuidString).swift"
        let file = tempDir.appendingPathComponent(fileName)
        try write(to: file, atomically: true, encoding: .utf8)
        let parsed = try SyntaxTreeParser.parse(file)
        let highlighter = SwiftHighlighterRewriter(code: self)
        _ = highlighter.visit(parsed)
        return highlighter.tokens
    }
}

struct CodeBlock {
    var text: String
    var range: NSRange
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

