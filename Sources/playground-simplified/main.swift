import CommonMark
import AppKit

// Minimal example from https://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
let app = NSApplication.shared
NSApp.setActivationPolicy(.regular)
let mainMenu = NSMenu(title: "My Menu")
let appItem = NSMenuItem()
let edit = NSMenuItem()
edit.title = "Edit"

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

let stdOutAttributes: [NSAttributedString.Key: Any] = [.font: NSFont(name: "Monaco", size: 12)!]
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
    var highlighter: Highlighter?
    var output: NSTextView?
    
    @objc func execute() {
        highlighter!.execute()
//        output?.textStorage?.append(NSAttributedString(string: out))
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
//        window.contentViewController = NSViewController()
        
        window.makeKeyAndOrderFront(nil)
        window.setFrameAutosaveName("PlaygroundWindow")
        let scrollView = NSScrollView(frame: window.contentView!.frame)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        let sidebarWidth: CGFloat = 200.0
        let rect = CGRect(origin: .zero, size: scrollView.contentSize)
        let (right, left) = rect.divided(atDistance: sidebarWidth, from: .maxXEdge)

        let field = NSTextView(frame: left)
        field.autoresizingMask = [.width, .height, .minYMargin]
        field.backgroundColor = .white
        field.textContainer?.containerSize = CGSize(width: left.width, height: .greatestFiniteMagnitude)
        field.isContinuousSpellCheckingEnabled = false
        field.isEditable = true
        field.backgroundColor = .textBackgroundColor
        field.textColor = .textColor
        field.insertionPointColor = .textColor
        
//        let defaultText = """
//        ```swift
//        1+1
//        ```
//        """
        let defaultText = try! String(contentsOfFile: "/Users/chris/objc.io/advanced-swift-book/02-Collections.md")
        field.textStorage?.setAttributedString(NSAttributedString(string: defaultText))
        
        
        

        let scrollView2 = NSScrollView(frame: right)
        scrollView2.borderType = .noBorder
        scrollView2.hasVerticalScroller = true
        scrollView2.hasHorizontalScroller = false
        scrollView2.autoresizingMask = [.minXMargin, .height]
        
        let field2 = NSTextView(frame: CGRect(origin: .zero, size: scrollView2.contentSize))
        field2.autoresizingMask = [.width, .height]
        field2.backgroundColor = .white
        field2.textContainer?.containerSize = CGSize(width: sidebarWidth, height: .greatestFiniteMagnitude)
        field2.isContinuousSpellCheckingEnabled = false
        field2.isEditable = false
        field2.backgroundColor = .white
        field2.textColor = .black
        
        scrollView2.documentView = field2
        
        output = field2
        
        highlighter = Highlighter(textView: field, output: field2)
        highlighter?.highlight()
        
        /*
        field2.textStorage?.setAttributedString(NSAttributedString(string: "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet."))
*/
        
        _ = NSView(frame: rect)
//        container.addSubview(field)
//        container.addSubview(field2)
//        container.autoresizingMask = [.width, .height]
//        container.wantsLayer = true
//        container.layer!.backgroundColor = NSColor.red.cgColor

        print(rect)
        print(scrollView.contentView.bounds)
        print(right)
        
        scrollView.addFloatingSubview(scrollView2, for: .vertical)
        scrollView.documentView = field
        window.contentView = scrollView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }
}


let appMenu = NSMenu()
let appName = ProcessInfo.processInfo.processName
let quitTitle = "Quit \(appName)"
let quitItem = NSMenuItem(title: quitTitle, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenu.addItem(quitItem)
appItem.submenu = appMenu
edit.submenu = NSTextView.defaultMenu
mainMenu.setSubmenu(NSTextView.defaultMenu, for: edit) // todo not entirely correct, should probably make the Edit menu ourselves.


let execute = NSMenuItem(title: "Execute", action: #selector(AppDelegate.execute), keyEquivalent: "e")
edit.submenu?.addItem(execute)
mainMenu.addItem(appItem)
mainMenu.addItem(edit)
app.mainMenu = mainMenu


let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
