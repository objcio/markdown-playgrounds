import CommonMark
import AppKit
import Ccmark

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

extension String {
    var lineOffsets: [String.Index] {
        var result = [startIndex]
        for i in indices {
            if self[i] == "\n" { // todo check if we also need \r and \r\n
                result.append(index(after: i))
            }
        }
        return result
    }
}

final class ViewController: NSViewController {
    let editor = NSTextView()
    let output = NSTextView()
    var observerToken: Any?
    
    override func loadView() {
        let editorSV = editor.configureAndWrapInScrollView(isEditable: true, inset: CGSize(width: 30, height: 10))
        let outputSV = output.configureAndWrapInScrollView(isEditable: false, inset: CGSize(width: 10, height: 10))
        outputSV.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        output.string = "output"
        editor.allowsUndo = true
        
        self.view = splitView([editorSV, outputSV])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        observerToken = NotificationCenter.default.addObserver(forName: NSTextView.didChangeNotification, object: editor, queue: nil) { [unowned self] _ in
            self.parse()
        }
    }
    
    func parse() {
        guard let attributedString = editor.textStorage else { return }
        attributedString.highlightMarkdown()
    }
    
    deinit {
        if let t = observerToken { NotificationCenter.default.removeObserver(t) }
    }
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

    func highlightMarkdown() {
        guard let node = Node(markdown: string) else { return }
        
        let lineOffsets = string.lineOffsets
        func index(of pos: Position) -> String.Index {
            let lineStart = lineOffsets[Int(pos.line-1)]
            return string.index(lineStart, offsetBy: Int(pos.column-1), limitedBy: string.endIndex) ?? string.endIndex
        }
        
        let defaultAttributes = Attributes(family: "Helvetica", size: 16)
        setAttributes(defaultAttributes.atts, range: range)
        
        node.visitAll(defaultAttributes) { c, attributes in
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
            default:
                break
            }
        }
    }
}


let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
