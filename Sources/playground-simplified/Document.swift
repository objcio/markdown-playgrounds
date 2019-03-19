//
//  Document.swift
//  CommonMark
//
//  Created by Chris Eidhof on 19.03.19.
//

import Foundation
import AppKit

final class MarkdownDocumentController: NSDocumentController {
    override var documentClassNames: [String] { return ["MarkdownDocument"] }
    override var defaultType: String? { return "MarkdownDocument" }
    override func documentClass(forType typeName: String) -> AnyClass? {
        return MarkdownDocument.self
    }
}

struct MarkdownError: Error { }

@objc(MarkdownDocument)
final class MarkdownDocument: NSDocument {
    static var cascadePoint = NSPoint.zero
    
    let contentViewController = ViewController()
    var text: String {
        get { return contentViewController.text }
        set { contentViewController.text = newValue }
    }
    
    override init() {
        super.init()
    }
    
    override class var readableTypes: [String] {
        return ["public.text"]
    }
    
    override class func isNativeType(_ type: String) -> Bool {
        return true
    }
    
    override func defaultDraftName() -> String {
        return "My Playground"
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw MarkdownError()
        }
        text = string
    }
    
    override func data(ofType typeName: String) throws -> Data {
        let text = contentViewController.editor.attributedString().string
        contentViewController.editor.breakUndoCoalescing()
        return text.data(using: .utf8)!
    }
    
    override func makeWindowControllers() {
        let window = NSWindow(contentViewController: contentViewController)
        window.styleMask.formUnion(.fullSizeContentView)
        window.setContentSize(NSSize(width: 800, height: 600))
        window.minSize = NSSize(width: 400, height: 200)
        
        let wc = NSWindowController(window: window)
        wc.contentViewController = contentViewController
        addWindowController(wc)
        
        window.setFrameTopLeftPoint(NSPoint(x: 5, y: (NSScreen.main?.visibleFrame.maxY ?? 0) - 5))
        MarkdownDocument.cascadePoint = window.cascadeTopLeft(from: MarkdownDocument.cascadePoint)
        window.makeKeyAndOrderFront(nil)
        window.setFrameAutosaveName(self.fileURL?.absoluteString ?? "empty")
    }
}
