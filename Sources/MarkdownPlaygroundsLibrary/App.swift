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
            let c = self[i]
            if c == "\n" || c == "\r" || c == "\r\n" {
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
    var codeBlocks: [CodeBlock] = []
    var repl: REPL!
    
    override func loadView() {
        let editorSV = editor.configureAndWrapInScrollView(isEditable: true, inset: CGSize(width: 30, height: 10))
        let outputSV = output.configureAndWrapInScrollView(isEditable: false, inset: CGSize(width: 10, height: 10))
        outputSV.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        editor.allowsUndo = true
        
        self.view = splitView([editorSV, outputSV])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        repl = REPL(onStdOut: { [unowned output] text in
            output.textStorage?.append(NSAttributedString(string: text, attributes: [
                .foregroundColor: NSColor.textColor
            ]))
        }, onStdErr: { [unowned output] text in
            output.textStorage?.append(NSAttributedString(string: text, attributes: [
                .foregroundColor: NSColor.red
            ]))
        })
        observerToken = NotificationCenter.default.addObserver(forName: NSTextView.didChangeNotification, object: editor, queue: nil) { [unowned self] _ in
            self.parse()
        }
        self.parse()
    }
    
    func parse() {
        guard let attributedString = editor.textStorage else { return }
        codeBlocks = attributedString.highlightMarkdown()
    }
    
    @objc func execute() {
        let pos = editor.selectedRange().location
        guard let block = codeBlocks.first(where: { $0.range.contains(pos) }) else { return }
        repl.execute(block.text)
    }
    
    deinit {
        if let t = observerToken { NotificationCenter.default.removeObserver(t) }
    }
}



struct REPLBuffer {
    private var buffer = Data()
    private let onResult: (String) -> ()
    
    init(onResult: @escaping (String) -> ()) {
        self.onResult = onResult
    }
    
    mutating func append(_ data: Data) {
        buffer.append(data)
        guard let s = String(data: buffer, encoding: .utf8), s.last?.isNewline == true else { return }
        buffer.removeAll()
        onResult(s)
    }
}

final class REPL {
    private let process = Process()
    private let stdIn = Pipe()
    private let stdErr = Pipe()
    private let stdOut = Pipe()
    private var stdOutToken: Any?
    private var stdErrToken: Any?
    private var stdOutBuffer: REPLBuffer
    private var stdErrBuffer: REPLBuffer

    init(onStdOut: @escaping (String) -> (), onStdErr: @escaping (String) -> ()) {
        process.launchPath = "/usr/bin/swift"
        process.standardInput = stdIn.fileHandleForReading
        process.standardOutput = stdOut.fileHandleForWriting
        process.standardError = stdErr.fileHandleForWriting
    
        self.stdOutBuffer = REPLBuffer { onStdOut($0) }
        self.stdErrBuffer = REPLBuffer { onStdErr($0) }

        stdOutToken = NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: stdOut.fileHandleForReading, queue: nil, using: { [unowned self] note in
            self.stdOutBuffer.append(self.stdOut.fileHandleForReading.availableData)
            self.stdOut.fileHandleForReading.waitForDataInBackgroundAndNotify()
        })

        stdErrToken = NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: stdErr.fileHandleForReading, queue: nil, using: { [unowned self] note in
            self.stdErrBuffer.append(self.stdErr.fileHandleForReading.availableData)
            self.stdErr.fileHandleForReading.waitForDataInBackgroundAndNotify()
        })

        process.launch()
        stdOut.fileHandleForReading.waitForDataInBackgroundAndNotify()
        stdErr.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }
    
    func execute(_ code: String) {
        stdIn.fileHandleForWriting.write(code.data(using: .utf8)!)
    }
    
    deinit {
        if let t = stdOutToken { NotificationCenter.default.removeObserver(t) }
        if let t = stdErrToken { NotificationCenter.default.removeObserver(t) }
    }
}


public func markdownPlaygroundsMain() {
    let delegate = AppDelegate()
    let app = application(delegate: delegate)
    app.run()
}
