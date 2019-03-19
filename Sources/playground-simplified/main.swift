import CommonMark
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
    }
}

let delegate = AppDelegate()
let app = application(delegate: delegate)
app.run()
