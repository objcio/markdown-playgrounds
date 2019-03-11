import CommonMark
import AppKit

// Minimal example from https://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
let app = NSApplication.shared
NSApp.setActivationPolicy(.regular)
let mainMenu = NSMenu(title: "My Menu")
let appItem = NSMenuItem()
let edit = NSMenuItem()
edit.title = "Edit"

// for stdout reading, see https://stackoverflow.com/questions/29548811/real-time-nstask-output-to-nstextview-with-swift
class REPL {
    var process: Process!
    let stdIn = Pipe()
    init() {
        self.process = Process()
        self.process.launchPath = "/usr/bin/swift"
        self.process.standardInput = self.stdIn
        self.process.launch()
    }
    
    var stdOut: FileHandle {
        return process.standardOutput as! FileHandle
    }
    
    func write(_ s: String) {
        self.stdIn.fileHandleForWriting.write(s.data(using: .utf8)!)
    }
}

// From: https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/
class Highlighter {
    let textView: NSTextView
    var observationToken: Any?
    var codeBlocks: [CodeBlock] = []
    
    let repl = REPL()
    
    init(textView: NSTextView) {
        self.textView = textView
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
    
    @objc func execute() {
        highlighter?.execute()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        let scrollView = NSScrollView(frame: window.contentView!.frame)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        let field = NSTextView(frame: CGRect(origin: .zero, size: scrollView.contentSize))
        field.minSize = CGSize(width: 0, height: scrollView.contentSize.height)
        field.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        field.isVerticallyResizable = true
        field.isHorizontallyResizable = true
        field.autoresizingMask = [.width]
        field.backgroundColor = .white
        field.textContainer?.containerSize = CGSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        field.isContinuousSpellCheckingEnabled = true
        field.isEditable = true
        field.backgroundColor = .textBackgroundColor
        field.textColor = .textColor
        field.insertionPointColor = .textColor
        
        //        let defaultText = try! String(contentsOfFile: "/Users/chris/objc.io/advanced-swift-book/Protocols.md")
        //        field.textStorage?.setAttributedString(NSAttributedString(string: defaultText))
        
        highlighter = Highlighter(textView: field)
        highlighter?.highlight()
        
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
