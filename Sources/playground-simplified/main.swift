import CommonMark
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // First instance becomes the shared document controller
        _ = MarkdownDocumentController()
    }
}

class MarkdownDocumentController: NSDocumentController {
    override var documentClassNames: [String] {
        return ["MarkdownDocument"]
    }
    
    override var defaultType: String? {
        return "MarkdownDocument"
    }
    
    override func documentClass(forType typeName: String) -> AnyClass? {
        return MarkdownDocument.self
    }
}

struct MarkdownError: Error { }

@objc(MarkdownDocument)
class MarkdownDocument: NSDocument {
    let contentViewController = ViewController()
    
    override class var readableTypes: [String] {
        return ["public.text"]
    }
    
    override class func isNativeType(_ name: String) -> Bool {
        return true
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        guard let str = String(data: data, encoding: .utf8) else {
            throw MarkdownError()
        }
        contentViewController.editor.string = str
    }
    
    override func data(ofType typeName: String) throws -> Data {
        contentViewController.editor.breakUndoCoalescing()
        return contentViewController.editor.string.data(using: .utf8)!
    }
    
    override func makeWindowControllers() {
        let window = NSWindow(contentViewController: contentViewController)
        window.setContentSize(NSSize(width: 800, height: 600))
        let wc = NSWindowController(window: window)
        wc.contentViewController = contentViewController
        addWindowController(wc)
        window.setFrameAutosaveName("windowFrame")
        window.makeKeyAndOrderFront(nil)
    }
}

final class ViewController: NSViewController {
    let editor = NSTextView()
    let output = NSTextView()
    override func loadView() {
        let editorSV = editor.configureAndWrapInScrollView(isEditable: true, inset: CGSize(width: 30, height: 10))
        let outputSV = output.configureAndWrapInScrollView(isEditable: false, inset: CGSize(width: 10, height: 10))
        outputSV.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        output.string = "output"
        editor.allowsUndo = true
        
        self.view = splitView([editorSV, outputSV])
    }
}

let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
