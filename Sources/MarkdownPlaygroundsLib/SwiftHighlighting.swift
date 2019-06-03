//
//  SwiftHighlighting.swift
//  CommonMark
//
//  Created by Chris Eidhof on 14.03.19.
//

import Foundation
import SwiftSyntax
import Foundation
import AppKit

extension Token.Kind {
    var color: NSColor {
        switch self {
        case .comment: return accentColors[0]
        case .keyword: return accentColors[4]
        case .number: return accentColors[3]
        case .string: return accentColors[2]
        }
    }
}

extension NSMutableAttributedString {
    func highlightCodeBlock(block: CodeBlock, result: SwiftHighlighter.Result) {
        let nsString = string as NSString
        let offset1 = (nsString.substring(with: block.range) as NSString).range(of: block.text).location
        if offset1 == NSNotFound { return } // error
        let start = block.range.location + offset1
        for el in result {
            let offset = NSRange(el.range, in: block.text)
            let theRange = NSRange(location: start + offset.location, length: offset.length)
            guard theRange.location >= 0, theRange.length < nsString.length else {
                print("invalid range: \(theRange)")
                continue
            }
            addAttribute(.foregroundColor, value: el.kind.color, range: theRange)
        }
    }
}

public class SwiftHighlighter {
    typealias Result = [(range: Range<String.Index>, kind: Token.Kind)]
    
    var cache: [String:Result] = [:]
    public init() { }
    
    func highlight(_ pieces: [String]) throws -> [Result] {
        // todo we probably only need to return (Block,Result) for the non-cached pieces!
        var combined: String = ""
        
        let ranges: [Range<String.Index>?] = pieces.map { piece in
            if cache[piece] != nil { return nil }
            let start = combined.endIndex
            combined.append(piece)
            let end = combined.endIndex
            combined.append("\n\n")
            return start..<end
        }
        
        // combined contains all the code that still needs to be highlighted
        // ranges contains the ranges of the to-be-highlighted pieces (in combined), and nil for each piece that's in the cache.
        
        let allResults = combined.isEmpty ? [] : try _highlight(combined)
        var separated: [Result] = zip(ranges, ranges.indices).map { (range, index) in
            if range == nil { return cache[pieces[index]]! } else { return [] }
        }
        // at this point, separated contains a non-nil entry for each cached piece.
    
        
        
        for var el in allResults {
            let currentIndex = ranges.firstIndex { $0?.contains(el.range.lowerBound) == true }!
            let distance = combined.distance(from: ranges[currentIndex]!.lowerBound, to: el.range.lowerBound)
            let piece = pieces[currentIndex]
            let start = piece.index(piece.startIndex, offsetBy: distance)
            let distance2 = combined.distance(from: el.range.lowerBound, to: el.range.upperBound)
            let end = piece.index(start, offsetBy: distance2, limitedBy: piece.endIndex) ?? piece.endIndex
            el.range = start..<end
            separated[currentIndex].append(el)
        }
        for (k,v) in zip(pieces,separated) {
            cache[k] = v
        }
        return separated
    }
    
    private func _highlight(_ code: String) throws -> Result {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileName = "\(UUID().uuidString).swift"
        let file = tempDir.appendingPathComponent(fileName)
        try! code.write(to: file, atomically: true, encoding: .utf8)
        let sourceFile = try! SyntaxTreeParser.parse(file)
        let highlighter = SwiftHighlighterRewriter()
        _ = highlighter.visit(sourceFile)
        
        let result: Result = highlighter.result.map { t in
            let start = code.utf8.index(code.utf8.startIndex, offsetBy: t.start.utf8Offset)
            let end = code.utf8.index(code.utf8.startIndex, offsetBy: t.end.utf8Offset)
            let result = start..<end
            return (result, t.kind)
        }
        
        try! FileManager.default.removeItem(at: file)
        return result
    }
}

struct Token {
    enum Kind {
        case string
        case number
        case keyword
        case comment
    }
    var kind: Kind
    var start: AbsolutePosition
    var end: AbsolutePosition
}

extension TokenSyntax {
    func enumerateAllTrivia(_ f: (TriviaPiece, _ start: AbsolutePosition, _ end: AbsolutePosition) -> ()) {
        var pos = position
        for piece in leadingTrivia {
            let endPos = pos + piece.sourceLength
            f(piece, pos, endPos)
            pos = endPos
        }
        
        pos = endPosition
        for piece in trailingTrivia {
            let endPos = pos + piece.sourceLength
            f(piece, pos, endPos)
            pos = endPos
        }
        
    }
}

extension TriviaPiece {
    var isComment: Bool {
        switch self {
        case .lineComment, .blockComment, .docBlockComment, .docLineComment:
            return true
        default:
            return false
        }
    }
}
class SwiftHighlighterRewriter: SyntaxRewriter {
    var result: [Token] = []
    override func visit(_ token: TokenSyntax) -> Syntax {
        let kind: Token.Kind?
        switch token.tokenKind {
        case .stringLiteral, .stringQuote, .stringSegment:
            kind = .string
        case .integerLiteral, .floatingLiteral:
            kind = .number
        case _ where token.tokenKind.isKeyword:
            kind = .keyword
        default:
            kind = nil
            //print("Unknown token: \(token.tokenKind) \(token)")
        }
        if let k = kind {
        	result.append(Token(kind: k, start: token.positionAfterSkippingLeadingTrivia, end: token.endPosition))
        }
        token.enumerateAllTrivia { piece, start, end in
            if piece.isComment {
                result.append(Token(kind: .comment, start: start, end: end))
            }
        }
        return token
    }
}
