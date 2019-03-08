//
//  Highlighting.swift
//  CommonMark
//
//  Created by Chris Eidhof on 08.03.19.
//

import Foundation
import CommonMark

enum NodeType: UInt32 {
    case none
    case document
    case block_quote
    case list
    case item
    case code_block
    case html_block
    case custom_block
    case paragraph
    case heading
    case thematic_break
    case first_block
    case last_block
    case text
    case softbreak
    case linebreak
    case code
    case html_inline
    case custom_inline
    case emph
    case strong
    case link
    case image
    case first_inline
    case last_inline
}

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
    .foregroundColor: NSColor.textColor,
    .font: NSFont.systemFont(ofSize: fontSize)
]


extension NSMutableAttributedString {
    var range: NSRange { return NSMakeRange(0, length) }
    
    func highlight() {
        beginEditing()
        setAttributes(defaults, range: range)
        let parsed = Node(markdown: string)
        let scalars = string.unicodeScalars
        let lineNumbers = string.unicodeScalars.lineIndices
        
        for el in parsed?.children ?? [] {
            guard let t = NodeType(rawValue: el.type.rawValue) else { continue }
            
            let start = scalars.index(lineNumbers[Int(el.start.line-1)], offsetBy: Int(el.start.column-1))
            let end = scalars.index(lineNumbers[Int(el.end.line-1)], offsetBy: Int(el.end.column-1))
            let range = start...end
            
            switch t {
            case .heading:
                addAttribute(.foregroundColor, value: NSColor.systemPink, range: NSRange(range, in: string))
            case .code_block:
                addAttribute(.font, value: NSFont(name: "Monaco", size: fontSize), range: NSRange(range, in: string))
            default:
                ()
            }
        }
        endEditing()
    }
}
