import CommonMark
import AppKit

// Minimal example from https://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
let app = NSApplication.shared
NSApp.setActivationPolicy(.regular)
let mainMenu = NSMenu(title: "My Menu")
let appItem = NSMenuItem()
let edit = NSMenuItem()
edit.title = "Edit"



let appMenu = NSMenu()
let appName = ProcessInfo.processInfo.processName
let quitTitle = "Quit \(appName)"
let quitItem = NSMenuItem(title: quitTitle, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appMenu.addItem(quitItem)
appItem.submenu = appMenu
edit.submenu = NSTextView.defaultMenu
mainMenu.setSubmenu(NSTextView.defaultMenu, for: edit) // todo not entirely correct, should probably make the Edit menu ourselves.

mainMenu.addItem(appItem)
mainMenu.addItem(edit)
app.mainMenu = mainMenu

// From: https://christiantietze.de/posts/2017/11/syntax-highlight-nstextstorage-insertion-point-change/
class Highlighter {
    let textView: NSTextView
    var observationToken: Any?
    init(textView: NSTextView) {
        self.textView = textView
        observationToken = NotificationCenter.default.addObserver(forName: NSText.didChangeNotification, object: textView, queue: nil) { [unowned self] note in
            self.highlight()
        }
    }
    
    func highlight() {
        textView.textStorage?.highlight()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSMakeRect(200, 200, 400, 200),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false,
                          screen: nil)
    var highlighter: Highlighter?
    
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
        
        let defaultText = try! String(contentsOfFile: "/Users/chris/objc.io/advanced-swift-book/Protocols.md")
        field.textStorage?.setAttributedString(NSAttributedString(string: defaultText))

        highlighter = Highlighter(textView: field)
        highlighter?.highlight()
        
        scrollView.documentView = field
        window.contentView = scrollView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
