import CommonMark
import AppKit

let stdOutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Monaco", size: 12)!, .foregroundColor: NSColor.textColor]
let stdErrAttributes: [NSAttributedString.Key: Any] = stdOutAttributes.merging([.foregroundColor: NSColor.red], uniquingKeysWith: { $1 })

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

final class ViewController: NSViewController {
    private var splitView = NSSplitView()
    let editor = NSTextView()
    let output = NSTextView()
    private var observationToken: Any?
    
    private var codeBlocks: [CodeBlock] = []
    private var repl: REPL!
    private let swiftHighlighter = SwiftHighlighter()

    
    var text: String {
        get {
            return editor.string
        }
        set {
            editor.string = newValue
            highlight()
        }
    }
    
    override func loadView() {
        let editorScrollView = editor.configureAndWrapInScrollView(isEditable: true, inset: CGSize(width: 30, height: 30))
        let outputScrollView = output.configureAndWrapInScrollView(isEditable: false, inset: CGSize(width: 10, height: 30))
        editor.allowsUndo = true
        let c = outputScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        c.priority = .defaultHigh
        c.isActive = true
        
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
        super.viewDidLoad()
        observationToken = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: editor, queue: nil) { [unowned self] note in
            self.highlight()
        }
        setupREPL()
    }
    
    deinit {
        if let t = observationToken { NotificationCenter.default.removeObserver(t) }
    }
    
    override func viewDidAppear() {
        view.window!.makeFirstResponder(editor)
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
        codeBlocks = att.highlightMarkdown(swiftHighlighter)
        guard !codeBlocks.isEmpty else { return }
        do {
            // if the call to highlight is *within* a `beginEditing` block, it crashes (!)
            let zipped = zip(codeBlocks, try self.swiftHighlighter.highlight(codeBlocks.map { $0.text }))
            for (block, result) in zipped {
                att.highlightCodeBlock(block: block, result: result)
            }
        } catch { print(error) }
    }
    
    @objc func execute() {
        guard let r = editor.selectedRanges.first?.rangeValue else { return }
        guard let found = codeBlocks.first(where: { ($0.range.lowerBound...$0.range.upperBound).contains(r.location) }) else { return }
        repl.evaluate(found.text)
    }
    
    @objc func executeAll() {
        for b in codeBlocks {
            if b.fenceInfo == "swift-error" || b.fenceInfo == "swift-example" { continue }
            repl.evaluate(b.text)
        }
    }
    
    @objc func reset() {
        setupREPL()
    }
}


let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
