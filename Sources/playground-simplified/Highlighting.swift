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

let fontSize: CGFloat = 14
let defaults: [NSAttributedString.Key: Any] = [
    .backgroundColor: NSColor.textBackgroundColor,
    .foregroundColor: NSColor.textColor,
    .font: NSFont.systemFont(ofSize: fontSize)
]

struct CodeBlock {
    let range: NSRange
    let fenceInfo: String?
    let text: String
}

extension CommonMark.Node {
    func visitAll(_ callback: (Node) -> ()) {
        for c in children {
            callback(c)
            c.visitAll(callback)
        }
    }
}

extension NSMutableAttributedString {
    var range: NSRange { return NSMakeRange(0, length) }
    
    func highlight() -> [CodeBlock] {
        beginEditing()
        setAttributes(defaults, range: range)
        guard let parsed = Node(markdown: string) else { return [] }
        let scalars = string.unicodeScalars
        let lineNumbers = string.unicodeScalars.lineIndices
        var result: [CodeBlock] = []
        parsed.visitAll { el in
            guard el.start.column > 0 && el.start.line > 0 else { return }
            let start = scalars.index(lineNumbers[Int(el.start.line-1)], offsetBy: Int(el.start.column-1))
            let end = scalars.index(lineNumbers[Int(el.end.line-1)], offsetBy: Int(el.end.column-1))
            guard start <= end else { return } // todo should be error?
            let range = start...end
            let nsRange = NSRange(range, in: string)
            switch el.type {
            case CMARK_NODE_HEADING:
                addAttribute(.foregroundColor, value: NSColor.systemPink, range: nsRange)
            case CMARK_NODE_CODE_BLOCK:
                addAttribute(.font, value: NSFont(name: "Monaco", size: fontSize)!, range: nsRange)
                result.append(CodeBlock(range: nsRange, fenceInfo: el.fenceInfo, text: el.literal!))
                if el.fenceInfo == "swift" {
                }
            default:
                ()
//                print(el.type)
            }
        }
        endEditing()
        return result
    }
}
