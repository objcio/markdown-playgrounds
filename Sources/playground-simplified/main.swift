import CommonMark
import AppKit


struct REPLParser {
    var buffer: Substring = "" {
        didSet { parse() }
    }
    private let onResult: (String) -> ()
    private let marker = UUID().uuidString
    
    init(onResult: @escaping (String) -> ()) {
        self.onResult = onResult
    }
    
    var startMarker: String { return "<\(marker)" }
    var endMarker: String { return ">\(marker)" }

    mutating func parse() {
        guard
            let startRange = buffer.range(of: startMarker),
            let endRange = buffer.range(of: endMarker)
        else { return }
        let start = buffer.index(after: startRange.upperBound)
        let end = endRange.lowerBound
        let output = buffer[start..<end]
        let lines: [Substring] = output.split(separator: "\n").map { line in
            var result = line
            if line.hasPrefix("$R"), let colonIdx = result.firstIndex(of: ":") {
                result = line[line.index(colonIdx, offsetBy: 2)...]
            }
            return result
        }
        buffer = buffer[endRange.upperBound...]
        onResult(lines.joined(separator: "\n"))
    }
}

class REPL {
    private var process: Process!
    private let stdIn = Pipe()
    private let onStdOut: (String) -> ()
    private let onStdErr: (String) -> ()
    private var token: Any?
    private let queue = DispatchQueue(label: "REPL Queue")
    private let marker = UUID().uuidString
    private var stdOutParser: REPLParser!
    private var stdErrBuffer = ""
    private var started = false
    
    init(onStdOut: @escaping (String) -> (), onStdErr: @escaping (String) -> ()) {
        self.onStdOut = onStdOut
        self.onStdErr = onStdErr
        self.stdOutParser = REPLParser { [unowned self] output in
            self.onStdOut(output)
            let err = self.stdErrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !err.isEmpty { self.onStdErr(err) }
            self.stdErrBuffer = ""
        }

        let stdOut = Pipe()
        let stdErr = Pipe()
        self.process = Process()
        self.process.launchPath = "/usr/bin/swift"
        self.process.standardInput = stdIn
        self.process.standardOutput = stdOut
        self.process.standardError = stdErr
        self.process.launch()

        // See: https://stackoverflow.com/questions/29548811/real-time-nstask-output-to-nstextview-with-swift
        token = NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: nil, queue: OperationQueue.main) { [unowned self] note in
            let handle = note.object as! FileHandle
            guard handle === stdOut.fileHandleForReading || handle == stdErr.fileHandleForReading else { return }
            defer { handle.waitForDataInBackgroundAndNotify() }
            let data = handle.availableData
            guard self.started else { return }
            let str = String(data: data, encoding: .utf8)!
            if handle === stdOut.fileHandleForReading {
                self.stdOutParser.buffer += str
            } else {
                self.stdErrBuffer += str
            }
        }
        
        stdOut.fileHandleForReading.waitForDataInBackgroundAndNotify()
        stdErr.fileHandleForReading.waitForDataInBackgroundAndNotify()
    }
    
    deinit {
        if let t = token { NotificationCenter.default.removeObserver(t) }
    }
    
    func evaluate(_ s: String) {
        started = true
        queue.async {
            let statements = """
            print("\(self.stdOutParser.startMarker)")
            \(s)
            print("\(self.stdOutParser.endMarker)")
            
            """
            self.stdIn.fileHandleForWriting.write(statements.data(using: .utf8)!)
        }
    }
}

let stdOutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Monaco", size: 12)!, .foregroundColor: NSColor.textColor]
let stdErrAttributes: [NSAttributedString.Key: Any] = stdOutAttributes.merging([.foregroundColor: NSColor.red], uniquingKeysWith: { $1 })

// From: https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/
class Highlighter {
    let editor: NSTextView
    var observationToken: Any?
    var codeBlocks: [CodeBlock] = []
    
    let repl: REPL
    
    init(textView: NSTextView, output: NSTextView) {
        self.editor = textView
        repl = REPL(onStdOut: {
            let text = $0.isEmpty ? "No output" : $0
            output.textStorage?.append(NSAttributedString(string: text + "\n", attributes: stdOutAttributes))
            output.scrollToEndOfDocument(nil)
        }, onStdErr: {
            output.textStorage?.append(NSAttributedString(string: $0 + "\n", attributes: stdErrAttributes))
            output.scrollToEndOfDocument(nil)
        })
        observationToken = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: textView, queue: nil) { [unowned self] note in
            self.highlight()
        }
    }
    
    deinit {
        if let t = observationToken { NotificationCenter.default.removeObserver(t) }
    }
    
    func highlight() {
        codeBlocks = editor.textStorage?.highlight() ?? []
    }
    
    func execute() {
        guard let r = editor.selectedRanges.first?.rangeValue else { return }
        guard let found = codeBlocks.first(where: { $0.range.contains(r.location) }) else { return }
        repl.evaluate(found.text)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let sharedController = MyDocumentController() // the first instance of `NSDocumentController` becomes the shared controller...
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
    }
}

final class MyDocumentController: NSDocumentController {
    override var documentClassNames: [String] { return ["MarkdownDocument"] }
    override var defaultType: String? { return "MarkdownDocument" } // todo
    override func documentClass(forType typeName: String) -> AnyClass? {
//        assert(typeName == "net.daringfireball.markdown")
        return MarkdownDocument.self
    }
    
    override func openDocument(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        beginOpenPanel(openPanel, forTypes: ["public.text"], completionHandler: { x in
            switch x {
            case NSApplication.ModalResponse.OK.rawValue:
                for url in openPanel.urls {
                    self.openDocument(withContentsOf: url, display: true, completionHandler: { (doc, bool, err) in
                        print(doc, bool, err) // todo: handle error?
                    })
                }
            default:
                ()
            }
            
        })
    }
}

extension String: Error { } // todo

final class MarkdownDocument: NSDocument {
    var contentViewController: ViewController?
    var text: String?
    
    override init() {
        super.init()
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        text = String(data: data, encoding: .utf8)!
        contentViewController?.text = text ?? ""
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        guard let text = contentViewController?.editor.attributedString().string else {
            throw "Can't get text"
        }
        let data = text.data(using: .utf8)!
        try data.write(to: url)
    }
    
    
    override func makeWindowControllers() {
        let window = NSWindow(contentRect: NSMakeRect(200, 200, 400, 200),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false,
                              screen: nil)
        window.makeKeyAndOrderFront(nil)

        window.setFrameAutosaveName(self.fileURL?.absoluteString ?? "")
        let wc = NSWindowController(window: window)
        let vc = ViewController()
        vc.text = self.text ?? ""
        wc.contentViewController = vc
        self.contentViewController = vc
        addWindowController(wc)
    }
}

final class ViewController: NSViewController {
    var highlighter: Highlighter!
    var splitView = NSSplitView()
    var editor: NSTextView!
    var output: NSTextView!
    
    var text: String = "" {
        didSet {
            editor?.textStorage?.setAttributedString(NSAttributedString(string: text))
            highlighter?.highlight()
        }
    }

    override func loadView() {
        let (editorScrollView, editor) = textView(isEditable: true, inset: CGSize(width: 30, height: 30))
        let (outputScrollView, output) = textView(isEditable: false, inset: CGSize(width: 10, height: 30))
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
        highlighter = Highlighter(textView: editor, output: output)
        highlighter.highlight()
    }
    
    override func viewDidAppear() {
        view.window!.makeFirstResponder(editor)
    }
    
    @objc func execute() {
        highlighter!.execute()
    }
}


let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
