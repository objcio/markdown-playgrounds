//
//  REPL.swift
//  CommonMark
//
//  Created by Chris Eidhof on 14.03.19.
//

import Foundation

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
        process.terminate()
    }
    
    func evaluate(_ s: String) {
        started = true
        let statements = """
        print("\(self.stdOutParser.startMarker)")
        \(s)
        print("\(self.stdOutParser.endMarker)")
        
        """
        self.stdIn.fileHandleForWriting.write(statements.data(using: .utf8)!)
    }
}
