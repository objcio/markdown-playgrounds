import XCTest
@testable import MarkdownPlaygroundsLibrary

final class playground_simplifiedTests: XCTestCase {
    func testUnicodeCorrectnessOfREPL() throws {
        let str = String(repeating: "👨‍👩‍👧‍👧", count: 500)
        let start = expectation(description: "started")
        let exp = expectation(description: "test")
        var ready = false
        let repl = REPL(onStdOut: { output in
            if ready {
                XCTAssertEqual(output, str + "\r\n")
                exp.fulfill()
            } else {
                ready = true
                start.fulfill()
            }
        }, onStdErr: { _ in })
        wait(for: [start], timeout: 5)
        repl.execute("print(\"\(str)\")\n")
        wait(for: [exp], timeout: 3)
    }
}
