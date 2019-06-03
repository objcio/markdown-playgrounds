//
//  Document.swift
//  CommonMark
//
//  Created by Chris Eidhof on 19.03.19.
//

import Foundation
import AppKit

let emptyDocumentText: String =
    """
    # Markdown Playgrounds

    This is an example document for [Markdown Playgrounds](https://github.com/objcio/markdown-playgrounds).

    ```swift
    1 + 1
    ```

    You can execute the code above by moving your cursor into the code block, and pressing *Cmd+E*.

    ```swift
    "hello".count
    ```

    Or press *Cmd+Shift+E* to execute all code blocks.

    ```swift-example
    // A swift-example code block never executes.
    struct Array {
    }
    ```
    """

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
        set {
            guard contentViewController.text != newValue else { return } // don't trigger unnecessary sets
            let i = contentViewController.text.indexOfFirstDifference(in: newValue)
            contentViewController.text = newValue
            if let j = i {
            	contentViewController.scrollTo(position: j)
            }
        }
    }
    
    override init() {
        super.init()
        text = emptyDocumentText
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
    
    override func presentedItemDidChange() {
        // todo: I think this could somehow be done more easily with file coordinators?
        guard let u = presentedItemURL else { return }
        DispatchQueue.main.async {
            do {
                guard !self.hasUnautosavedChanges else {
                    Swift.print("Not going to observe changes because the document is dirty.")
                    return
                }
                let contents = try Data(contentsOf: u)
                try self.read(from: contents, ofType: "")
            } catch {
                Swift.print(error)
            }
    	}
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
