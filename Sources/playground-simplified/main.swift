import CommonMark
import AppKit

let stdOutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Monaco", size: 12)!, .foregroundColor: NSColor.textColor]
let stdErrAttributes: [NSAttributedString.Key: Any] = stdOutAttributes.merging([.foregroundColor: NSColor.red], uniquingKeysWith: { $1 })


// From: https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/
class HighlightController {
    private let editor: NSTextView
    private let output: NSTextView
    private var observationToken: Any?
    private var codeBlocks: [CodeBlock] = []
    private var repl: REPL!
    private let swiftHighlighter = SwiftHighlighter()
    
    init(editor: NSTextView, output: NSTextView) {
        self.editor = editor
        self.output = output
        setupREPL()
        observationToken = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: editor, queue: nil) { [unowned self] note in
            self.highlight()
        }
    }
    
    deinit {
        if let t = observationToken { NotificationCenter.default.removeObserver(t) }
    }
    
    private func setupREPL() {
        repl = REPL(onStdOut: {
            let text = $0.isEmpty ? "No output" : $0
            self.output.textStorage?.append(NSAttributedString(string: text + "\n", attributes: stdOutAttributes))
            self.output.scrollToEndOfDocument(nil)
        }, onStdErr: {
            self.output.textStorage?.append(NSAttributedString(string: $0 + "\n", attributes: stdErrAttributes))
            self.output.scrollToEndOfDocument(nil)
        })
    }
    
    func highlight() {
        guard let att = editor.textStorage else { return }
        att.beginEditing()
        codeBlocks = att.highlight(swiftHighlighter)
        att.endEditing()
        guard !codeBlocks.isEmpty else { return }
        do {
            // if the call to highlight is *within* a `beginEditing` block, it crashes (!)
            let zipped = zip(codeBlocks, try self.swiftHighlighter.highlight(codeBlocks.map { $0.text }))
            att.beginEditing()
            for (block, result) in zipped {
                att.highlight(block: block, result: result)
            }
            att.endEditing()
        } catch { print(error) }
    }
    
    func execute() {
        guard let r = editor.selectedRanges.first?.rangeValue else { return }
        guard let found = codeBlocks.first(where: { $0.range.contains(r.location) }) else { return }
        repl.evaluate(found.text)
    }
    
    func executeAll() {
        for b in codeBlocks {
            if b.fenceInfo == "swift-error" || b.fenceInfo == "swift-example" { continue }
            repl.evaluate(b.text)
        }
    }
    
    func reset() {
        setupREPL()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = MyDocumentController() // the first instance of `NSDocumentController` becomes the shared controller...
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
    }
}

final class MyDocumentController: NSDocumentController {
    override var documentClassNames: [String] { return ["MarkdownDocument"] }
    override var defaultType: String? { return "MarkdownDocument" }
    override func documentClass(forType typeName: String) -> AnyClass? {
        return MarkdownDocument.self
    }
    
    override func openDocument(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        beginOpenPanel(openPanel, forTypes: ["public.text"], completionHandler: { x in
            switch x {
            case NSApplication.ModalResponse.OK.rawValue:
                for url in openPanel.urls {
                    self.openDocument(withContentsOf: url, display: true, completionHandler: { (doc, bool, err) in })
                }
            default:
                ()
            }

        })
    }
}

struct MarkdownError: Error { }

final class MarkdownDocument: NSDocument {
    var contentViewController: ViewController?
    var text: String?
    
    override init() {
        super.init()
    }
    
    override class func isNativeType(_ type: String) -> Bool {
        return true
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        text = String(data: data, encoding: .utf8)!
        contentViewController?.text = text ?? ""
    }
    
    override func data(ofType typeName: String) throws -> Data {
        guard let text = contentViewController?.editor.attributedString().string else {
            throw MarkdownError()
        }
        contentViewController?.editor.breakUndoCoalescing()
        return text.data(using: .utf8)!
    }
    
    override func makeWindowControllers() {
        let vc = ViewController()
        contentViewController = vc
        vc.text = self.text ?? ""
        let window = NSWindow(contentViewController: vc)
        window.setContentSize(NSSize(width: 800, height: 600))
        window.minSize = NSSize(width: 400, height: 200)
        let wc = NSWindowController(window: window)
        wc.contentViewController = vc
        addWindowController(wc)
        window.makeKeyAndOrderFront(nil)
        // TODO we should cascade new window positions
        window.center()
        window.setFrameAutosaveName(self.fileURL?.absoluteString ?? "empty")
    }
}

final class ViewController: NSViewController {
    private var highlighter: HighlightController!
    private var splitView = NSSplitView()
    private(set) var editor: NSTextView!
    private(set) var output: NSTextView!
    
    var text: String = "" {
        didSet {
            editor?.textStorage?.setAttributedString(NSAttributedString(string: text))
            highlighter?.highlight()
        }
    }

    override func loadView() {
        let (editorScrollView, editor) = textView(isEditable: true, inset: CGSize(width: 30, height: 30))
        let (outputScrollView, output) = textView(isEditable: false, inset: CGSize(width: 10, height: 30))
        editor.allowsUndo = true
        self.editor = editor
        self.output = output
        let c = outputScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        c.priority = .defaultHigh
        c.isActive = true
        self.text = text + "" // trigger didSet
        
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(editorScrollView)
        splitView.addArrangedSubview(outputScrollView)
        splitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 0)
        splitView.autoresizingMask = [.width, .height]
        splitView.autosaveName = "SplitView"
        self.view = splitView
    }
    
    override func viewDidLoad() {
        highlighter = HighlightController(editor: editor, output: output)
        highlighter.highlight()
    }
    
    override func viewDidAppear() {
        view.window!.makeFirstResponder(editor)
    }
    
    @objc func execute() {
        highlighter!.execute()
    }
    
    @objc func executeAll() {
        highlighter!.executeAll()
    }
    
    @objc func reset() {
        output.textStorage?.setAttributedString(NSAttributedString(string: ""))
        highlighter.reset()
    }
}


let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
