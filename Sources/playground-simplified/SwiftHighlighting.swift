//
//  SwiftHighlighting.swift
//  CommonMark
//
//  Created by Chris Eidhof on 14.03.19.
//

import Foundation
import SwiftSyntax
import Foundation


class SwiftHighlighter {
    func highlight<S: StringProtocol>(_ code: S) throws -> [(range: Range<String.Index>, kind: Token.Kind)] {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileName = "\(UUID().uuidString).swift"
        let file = tempDir.appendingPathComponent(fileName)
        defer { try? FileManager.default.removeItem(at: file) }
        try code.write(to: file, atomically: true, encoding: .utf8)
        
        let sourceFile = try SyntaxTreeParser.parse(file)
        let highlighter = SwiftHighlighterRewriter()
        _ = highlighter.visit(sourceFile)
        
        return highlighter.result.map { t in
            let start = code.utf8.index(code.utf8.startIndex, offsetBy: t.start.utf8Offset)
            let end = code.utf8.index(code.utf8.startIndex, offsetBy: t.end.utf8Offset)
            let result = start..<end
            return (result, t.kind)
        }
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
        token.trailingTrivia
        if let k = kind {
        	result.append(Token(kind: k, start: token.positionAfterSkippingLeadingTrivia, end: token.endPosition))
        }
        return token
    }
}
