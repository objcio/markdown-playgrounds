import XCTest
import class Foundation.Bundle

let sample = """
struct ReplacingStream: TextOutputStream, TextOutputStreamable {
    let toReplace: KeyValuePairs<String, String>
    private var output = ""

    init(replacing toReplace: KeyValuePairs<String, String>) {
        self.toReplace = toReplace
    }

    mutating func write(_ string: String) {
        let toWrite = toReplace.reduce(string) { partialResult, pair in
            partialResult.replacingOccurrences(of: pair.key, with: pair.value)
        }
        print(toWrite, terminator: "", to: &output)
    }

    func write<Target: TextOutputStream>(to target: inout Target) {
        output.write(to: &target)
    }
}

var replacer = ReplacingStream(replacing: [
    "in the cloud": "on someone else's computer"
])

let source = "People find it convenient to store their data in the cloud."
print(source, terminator: "", to: &replacer)

Hello



var output = ""
print(replacer, terminator: "", to: &output)
/*show*/ output
"""

@testable import MarkdownPlaygroundsLib

final class MarkdownPlaygroundTests: XCTestCase {
    func testExample() throws {
    }
    
    func testPerformance1() throws {
        let highlighter = SwiftHighlighter()
        measure {
        	let result = try! highlighter.highlight([sample])
            print(result)
        }
    }
    
    func testPerformance2() throws {
        var codeBlocks: [CodeBlock] = []
        let string = try! String(contentsOfFile: "/Users/chris/objc.io/advanced-swift-book/07-Strings.md")
        let swiftHighlighter = SwiftHighlighter()

        let att = NSTextStorage(string: string)
        func foo() {
            codeBlocks = att.highlightMarkdown(swiftHighlighter, codeBlocks: codeBlocks)
            guard !codeBlocks.isEmpty else { return }
            do {
                // if the call to highlight is *within* a `beginEditing` block, it crashes (!)
                let filtered = codeBlocks.filter { swiftHighlighter.cache[$0.text] == nil }
                let zipped = zip(filtered, try swiftHighlighter.highlight(filtered.map { $0.text }))
                for (block, result) in zipped {
//                    att.highlightCodeBlock(block: block, result: result)
                }
            } catch { print(error) }
        }
        foo()
//        let loc = (att.string as NSString).range(of: "print(replacer")
        att.insert(NSAttributedString(string: "\n"), at: 85250)
        measure { foo() }
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
