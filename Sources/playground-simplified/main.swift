import CommonMark
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var applicationHasStarted = false
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // the first instance of `NSDocumentController` becomes the shared controller...
        _ = MarkdownDocumentController()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        applicationHasStarted = true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        guard !applicationHasStarted else { return true }
        let controller = NSDocumentController.shared
        guard let recent = controller.recentDocumentURLs.first else { return true }
        controller.openDocument(withContentsOf: recent, display: true, completionHandler: { _, _, _ in () })
        return false
    }
}

let stdOutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Monaco", size: 12)!, .foregroundColor: NSColor.textColor]
let stdErrAttributes: [NSAttributedString.Key: Any] = stdOutAttributes.merging([.foregroundColor: NSColor.red], uniquingKeysWith: { $1 })

final class ViewController: NSViewController {
    let editor = NSTextView()
    let output = NSTextView()
    private var observationToken: Any?
    
    private var codeBlocks: [CodeBlock] = []
    private var repl: REPL<CodeBlock>?
    private let swiftHighlighter = SwiftHighlighter()

    
    var text: String {
        get { return editor.string }
        set {
            editor.string = newValue
            highlight()
        }
    }
    
    override func loadView() {
        let editorScrollView = editor.configureAndWrapInScrollView(isEditable: true, inset: CGSize(width: 30, height: 30))
        let outputScrollView = output.configureAndWrapInScrollView(isEditable: false, inset: CGSize(width: 10, height: 30))
        output.delegate = self
        output.linkTextAttributes = [.cursor: NSCursor.pointingHand]
        editor.allowsUndo = true
        let c = outputScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        c.priority = .defaultHigh
        c.isActive = true
        
        self.view = splitView([editorScrollView, outputScrollView])
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
        repl = REPL(onOutput: { [unowned self] out in
            let codeblock = out.metadata
            if let i = self.codeBlocks.firstIndex(where: { $0 == codeblock }) {
                if self.codeBlocks[i].error != out.stdErr {
                    self.codeBlocks[i].error = out.stdErr
                    self.highlight()
                }
            }
            let text = out.stdOut.isEmpty ? "No output" : out.stdOut
            var atts = stdOutAttributes
            atts[.link] = codeblock.range
            self.output.textStorage?.append(NSAttributedString(string: text + "\n", attributes: atts))
            if let e = out.stdErr {
                var atts = stdErrAttributes
                atts[.link] = codeblock.range
                self.output.textStorage?.append(NSAttributedString(string: e + "\n", attributes: atts))
                self.scrollToError(codeblock.range)
            }
            self.output.scrollToEndOfDocument(nil)
        })
    }
    
    func highlight() {
        guard let att = editor.textStorage else { return }
        codeBlocks = att.highlightMarkdown(swiftHighlighter, codeBlocks: codeBlocks)
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
        repl?.evaluate(found.text, metadata: found)
    }
    
    @objc func executeAll() {
        for b in codeBlocks {
            if b.fenceInfo == "swift-error" || b.fenceInfo == "swift-example" { continue }
            repl?.evaluate(b.text, metadata: b)
        }
    }
    
    @objc func reset() {
        setupREPL()
        for i in codeBlocks.indices { codeBlocks[i].error = nil } // reset error states
        output.string = ""
        highlight() // resets the error state in code blocks
    }
    
    func scrollToError(_ range: NSRange) {
        editor.scrollRangeToVisible(range)
        editor.selectedRanges = [NSValue(range: NSRange(location: range.location, length: 0))]
        editor.window?.makeFirstResponder(editor)
    }
}

extension ViewController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let u = link as? NSRange else { return false }
        scrollToError(u)
        return true
    }
}


let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
