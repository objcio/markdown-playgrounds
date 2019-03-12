import CommonMark
import AppKit


extension Pipe {
    func readUntil(suffix str: String) -> String {
        var all = Data()
        while true {
            fileHandleForReading.waitForDataInBackgroundAndNotify()
            let data = fileHandleForReading.availableData
            all.append(data)
            if let s = String(data: all, encoding: .utf8) {
                if s.hasSuffix(str) { return String(s.dropLast(str.count)) }
            }
        }
    }
}
// for stdout reading, see https://stackoverflow.com/questions/29548811/real-time-nstask-output-to-nstextview-with-swift
class REPL {
    var process: Process!
    let stdIn = Pipe()
    let stdOut = Pipe()
    let stdErr = Pipe()
    let onStdOut: (String) -> ()
    let onStdErr: (String) -> ()
    
    let stdOutQueue = DispatchQueue(label: "stdout")
    let stdErrQueue = DispatchQueue(label: "stderr")
    
    init(onStdOut: @escaping (String) -> (), onStdErr: @escaping (String) -> ()) {
        self.process = Process()
        self.process.launchPath = "/usr/bin/swift"
        self.process.standardInput = self.stdIn
        self.process.standardOutput = self.stdOut
        self.process.standardError = self.stdErr
        self.process.launch()
        self.onStdOut = onStdOut
        self.onStdErr = onStdErr
        
        stdOutQueue.async {
            while true {            self.stdOut.fileHandleForReading.waitForDataInBackgroundAndNotify()
                let data = self.stdOut.fileHandleForReading.availableData
                let str = String(data: data, encoding: .utf8)!
                DispatchQueue.main.async {
                    self.onStdOut(str)
                }
            }
        }
        
        stdErrQueue.async {
            while true {            self.stdErr.fileHandleForReading.waitForDataInBackgroundAndNotify()
                let data = self.stdErr.fileHandleForReading.availableData
                let str = String(data: data, encoding: .utf8)!
                DispatchQueue.main.async {
                    self.onStdErr(str)
                }
            }
        }
//        _ = stdOut.fileHandleForReading.availableData // read the initial prompt
    }
    
    func write(_ s: String) {
        let longStr = UUID().uuidString
        let theStr = """
        print("start: \(longStr)")
        \(s)
        print("end: \(longStr)")
        
        """
        self.stdIn.fileHandleForWriting.write(theStr.data(using: .utf8)!)
//        return self.stdOut.readUntil(suffix: longStr + "\r\n")
    }
}

let stdOutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Monaco", size: 12)!, .foregroundColor: NSColor.textColor]
let stdErrAttributes: [NSAttributedString.Key: Any] = stdOutAttributes.merging([.foregroundColor: NSColor.red], uniquingKeysWith: { $1 })

// From: https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/
class Highlighter {
    let textView: NSTextView
    var observationToken: Any?
    var codeBlocks: [CodeBlock] = []
    
    let repl: REPL
    
    init(textView: NSTextView, output: NSTextView) {
        self.textView = textView
        repl = REPL(onStdOut: {
            output.textStorage?.append(NSAttributedString(string: $0, attributes: stdOutAttributes))
            output.scrollToEndOfDocument(nil)
        }, onStdErr: {
            output.textStorage?.append(NSAttributedString(string: $0, attributes: stdErrAttributes))
            output.scrollToEndOfDocument(nil)
        })
        observationToken = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: textView, queue: nil) { [unowned self] note in
            self.highlight()
        }
    }
    
    func highlight() {
        codeBlocks = textView.textStorage?.highlight() ?? []
    }
    
    func execute() {
        guard let r = textView.selectedRanges.first?.rangeValue else { return }
        guard let found = codeBlocks.first(where: { $0.range.contains(r.location) }) else { return } // todo
        
        repl.write(found.text)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSMakeRect(200, 200, 400, 200),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false,
                          screen: nil)
    var highlighter: Highlighter!
    var output: NSTextView!
    
    @objc func execute() {
        highlighter!.execute()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.setFrameAutosaveName("PlaygroundWindow")
        
        let (editorScrollView, editor) = textView(isEditable: true, inset: CGSize(width: 30, height: 30))
        let (outputScrollView, output) = textView(isEditable: false, inset: CGSize(width: 10, height: 0))
        let c = outputScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        c.priority = .defaultHigh
        c.isActive = true
        
        editor.textStorage?.setAttributedString(NSAttributedString(string: """
		Hello, world.

		*This is my text* .

		- Here’s a list
		- And another item
		- And another

		This is a paragraph, a [link](https://www.objc.io), *bold*, **emph**, and ***both***.

		# A header with `inline` and *emph*.

		```swift
		1 + 1
		```
		"""))
        
        highlighter = Highlighter(textView: editor, output: output)
        highlighter.highlight()
        
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(editorScrollView)
        splitView.addArrangedSubview(outputScrollView)
        splitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 0)

        highlighter = Highlighter(textView: editor, output: output)
        highlighter.highlight()

        window.contentView = splitView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(editor)
    }
}


let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
