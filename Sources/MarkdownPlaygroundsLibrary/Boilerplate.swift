//
//  Boilerplate.swift
//  CommonMark
//
//  Created by Florian Kugler on 12-03-2019.
//

import Cocoa

func application(delegate: AppDelegate) -> NSApplication {
    // Inspired by https://www.cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
    let app = NSApplication.shared
    NSApp.setActivationPolicy(.regular)
    app.mainMenu = app.customMenu
    app.delegate = delegate
    app.applicationIconImage = NSImage.appIcon
    return app
}

func splitView(_ views: [NSView]) -> NSSplitView {
    let sv = NSSplitView()
    sv.isVertical = true
    sv.dividerStyle = .thin
    for v in views {
        sv.addArrangedSubview(v)
    }
    sv.setHoldingPriority(.defaultLow - 1, forSubviewAt: 0)
    sv.autoresizingMask = [.width, .height]
    sv.autosaveName = "SplitView"
    return sv

}

extension NSTextView {
    func configureAndWrapInScrollView(isEditable editable: Bool, inset: CGSize) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        
        isEditable = editable
        textContainerInset = inset
        autoresizingMask = [.width]
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        scrollView.documentView = self
        return scrollView
    }
}

extension NSImage {
	public static func drawn(width: CGFloat, height: CGFloat, flipped: Bool = false, _ function: @escaping (CGContext, CGRect) -> Void) -> NSImage {
		return NSImage(size: CGSize(width: width, height: height), flipped: flipped) { rect -> Bool in
			guard let context = NSGraphicsContext.current else { return false }
			function(context.cgContext, rect)
			return true
		}
	}
	
	public static var appIcon: NSImage {
		return NSImage.drawn(width: 128, height: 128) { context, bounds in
			context.rotate(by: 0.14)
			let box = bounds.insetBy(dx: 16, dy: 16).offsetBy(dx: 16, dy: -16)
            context.setFillColor(NSColor(white: 0.1, alpha: 1).cgColor)
            context.setStrokeColor(NSColor(white: 0.9, alpha: 0.75).cgColor)
            context.fill(box)
            context.stroke(box)
			let attributes: [NSAttributedString.Key: Any] =
                [.foregroundColor: NSColor.orange.cgColor, .font: NSFont(name: "Menlo", size: 14)!]
			let string = "```\nlet x = 5\nprint(x)\n```"
			let text = NSAttributedString(string: string, attributes: attributes)
			let framesetter = CTFramesetterCreateWithAttributedString(text)
            let textRange = CFRangeMake(0, text.length)
            let textContainerPath =  CGPath(rect: box.insetBy(dx: 8, dy: 8), transform: nil)
			let frame = CTFramesetterCreateFrame(framesetter, textRange, textContainerPath, nil)
			context.textPosition = CGPoint(x: 8, y: 24)
			CTFrameDraw(frame, context)
		}
	}
}

extension NSApplication {
    var customMenu: NSMenu {
        let appMenu = NSMenuItem()
        appMenu.submenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.submenu?.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.submenu?.addItem(NSMenuItem.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        self.servicesMenu = NSMenu()
        services.submenu = self.servicesMenu
        appMenu.submenu?.addItem(services)
        appMenu.submenu?.addItem(NSMenuItem.separator())
        appMenu.submenu?.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.submenu?.addItem(hideOthers)
        appMenu.submenu?.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.submenu?.addItem(NSMenuItem.separator())
        appMenu.submenu?.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let fileMenu = NSMenuItem()
        fileMenu.submenu = NSMenu(title: "File")
        fileMenu.submenu?.addItem(NSMenuItem(title: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n"))
        fileMenu.submenu?.addItem(NSMenuItem(title: "Open", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o"))
        fileMenu.submenu?.addItem(NSMenuItem.separator())
        fileMenu.submenu?.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenu.submenu?.addItem(NSMenuItem(title: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s"))
        fileMenu.submenu?.addItem(NSMenuItem(title: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: ""))

        let editMenu = NSMenuItem()
        editMenu.submenu = NSMenu(title: "Edit")
        editMenu.submenu?.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.submenu?.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.submenu?.addItem(NSMenuItem.separator())
        editMenu.submenu?.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.submenu?.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.submenu?.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.submenu?.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        let codeMenu = NSMenuItem()
        codeMenu.submenu = NSMenu(title: "Code")
        codeMenu.submenu?.addItem(NSMenuItem(title: "Execute", action: #selector(ViewController.execute), keyEquivalent: "e"))
        
        let windowMenu = NSMenuItem()
        windowMenu.submenu = NSMenu(title: "Window")
        windowMenu.submenu?.addItem(NSMenuItem(title: "Minmize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.submenu?.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.submenu?.addItem(NSMenuItem.separator())
        windowMenu.submenu?.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "m"))
        
        let mainMenu = NSMenu(title: "Main Menu")
        mainMenu.addItem(appMenu)
        mainMenu.addItem(fileMenu)
        mainMenu.addItem(editMenu)
        mainMenu.addItem(codeMenu)
        mainMenu.addItem(windowMenu)
        return mainMenu
    }
}

let accentColors: [NSColor] = [
    // From: https://ethanschoonover.com/solarized/#the-values
    (181, 137,   0),
    (203,  75,  22),
    (220,  50,  47),
    (211,  54, 130),
    (108, 113, 196),
    ( 38, 139, 210),
    ( 42, 161, 152),
    (133, 153,   0)
    ].map { NSColor(calibratedRed: CGFloat($0.0) / 255, green: CGFloat($0.1) / 255, blue: CGFloat($0.2) / 255, alpha: 1)}
