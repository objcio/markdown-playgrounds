//
//  MarkdownProcessing.swift
//  CommonMark
//
//  Created by Chris Eidhof on 26.03.19.
//

import Foundation

public enum ListType {
    case unordered
    case ordered
}

// todo: add state?

public struct Inline<A> {
    var text: (_ text: String) -> A
    var softBreak: A
    var lineBreak: A
    var code: (_ text: String) -> A
    var html: (_ text: String) -> A
    var emphasis: (_ children: [A]) -> A
    var strong: (_ children: [A]) -> A
    var custom: (_ literal: String) -> A
    var link: (_ children: [A], _ title: String?,  _ url: String?) -> A
    var image: (_ children: [A], _ title: String?, _ url: String?) -> A
}
/// A block-level element in a Markdown abstract syntax tree.
public struct Block<A> {
    var inline: Inline<A>
    var list: (_ items: [A], _ type: ListType) -> A
    var listItem: (_ children: [A]) -> A
    var blockQuote: (_ items: [A]) -> A
    var codeBlock: (_ text: String, _ language: String?) -> A
    var html: (_ text: String) -> A
    var paragraph: (_ text: [A]) -> A
    var heading: (_ text: [A], _ level: Int) -> A
    var custom: (_ literal: String) -> A
    var thematicBreak: A
    var document: (_ children: [A]) -> A
    
    var defaultValue: A
}

import CommonMark
import Ccmark

extension Node {
    func reduce<R>(_ b: Block<R>) -> R {
        func r(_ node: Node) -> R {
            var children: [R] { return node.children.map(r) }
            var lit: String { return node.literal ?? "" }
            switch node.type {
            case CMARK_NODE_DOCUMENT: return b.document(children)
            case CMARK_NODE_BLOCK_QUOTE: return b.blockQuote(children)
            case CMARK_NODE_LIST: return b.list(children, node.listType == CMARK_BULLET_LIST ? .unordered : .ordered)
            case CMARK_NODE_ITEM: return b.listItem(children)
            case CMARK_NODE_CODE_BLOCK: return b.codeBlock(lit, node.fenceInfo)
            case CMARK_NODE_HTML_BLOCK: return b.html(lit)
            case CMARK_NODE_CUSTOM_BLOCK: return b.custom(lit)
            case CMARK_NODE_PARAGRAPH: return b.paragraph(children)
            case CMARK_NODE_HEADING: return b.heading(children, node.headerLevel)
            case CMARK_NODE_THEMATIC_BREAK: return b.thematicBreak
            case CMARK_NODE_FIRST_BLOCK: return b.defaultValue
            case CMARK_NODE_LAST_BLOCK: return b.defaultValue
                
                /* Inline */
            case CMARK_NODE_TEXT: return b.inline.text(lit)
            case CMARK_NODE_SOFTBREAK: return b.inline.softBreak
            case CMARK_NODE_LINEBREAK: return b.inline.lineBreak
            case CMARK_NODE_CODE: return b.inline.code(lit)
            case CMARK_NODE_HTML_INLINE: return b.inline.html(lit)
            case CMARK_NODE_CUSTOM_INLINE: return b.inline.custom(lit)
            case CMARK_NODE_EMPH: return b.inline.emphasis(children)
            case CMARK_NODE_STRONG: return b.inline.strong(children)
            case CMARK_NODE_LINK: return b.inline.link(children, node.title, node.urlString)
            case CMARK_NODE_IMAGE: return b.inline.image(children, node.title, node.urlString)
            default:
                return b.defaultValue
            }
        }
        return r(self)
    }
}

protocol Monoid {
    init()
    static func +(lhs: Self, rhs: Self) -> Self
    mutating func append(_ value: Self)
}

extension Monoid {
    mutating func append(_ value: Self) {
        self = self + value
    }
}

extension Array: Monoid { }

extension Array where Element: Monoid {
    func flatten() -> Element {
        return reduce(into: .init(), { $0.append($1) })
    }
}

extension String: Monoid { }

struct Add: Monoid {
    static func + (lhs: Add, rhs: Add) -> Add {
        return Add(lhs.value + rhs.value)
    }
    
    var value: Int = 0    
    init() { self.value = 0 }
    init(_ value: Int) { self.value = value }
}

func collect<M: Monoid>() -> Block<M> {
    let inline: Inline<M> = Inline<M>(text: { _ in .init() }, softBreak: .init(), lineBreak: .init(), code: { _ in .init()}, html: { _ in .init() }, emphasis: { $0.flatten() }, strong: { $0.flatten() }, custom: { _ in .init() }, link: { x,_,_ in x.flatten() }, image: { x,_, _ in x.flatten() })
    
    return Block<M>(inline: inline, list: { x, _ in x.flatten() }, listItem: { $0.flatten() }, blockQuote: { $0.flatten() }, codeBlock: { _,_ in .init() }, html: { _ in .init() }, paragraph: { $0.flatten() }, heading: { x,_ in x.flatten() }, custom: { _ in .init() }, thematicBreak: .init(), document: { $0.flatten() }, defaultValue: .init())
}

func zip<A,B>(_ lhs: Block<A>, rhs: Block<B>) -> Block<(A,B)> {
    fatalError()
}

func map<A,B>(_ lhs: Block<A>, _ f: (A) -> B) -> Block<B> {
    fatalError()
}
