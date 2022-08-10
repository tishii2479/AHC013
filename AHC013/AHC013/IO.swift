#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Foundation

enum IO {}

// MARK: IO.Input
extension IO {
    static func readStringArray() -> [String] {
        guard let str = readLine() else {
            fatalError("Failed to read integer array")
        }
        return str.components(separatedBy: " ")
    }

    static func readIntArray() -> [Int] {
        let val: [Int] = readStringArray().map {
            guard let i = Int($0) else {
                fatalError("Failed to parse integer array")
            }
            return i
        }
        return val
    }

    static func readInt() -> Int {
        let arr = readIntArray()
        guard arr.count == 1 else {
            fatalError("Failed to read integer")
        }
        return arr[0]
    }
    
    static func readString() -> String {
        let arr = readStringArray()
        guard arr.count == 1 else {
            fatalError("Failed to read string")
        }
        return arr[0]
    }
    
}

// MARK: IO.Output
extension IO {
    enum LogType: String {
        case none   = ""
        case log    = "[LOG]"
        case debug  = "[DEBUG]"
        case info   = "[INFO]"
        case warn   = "[WARN]"
        case error  = "[ERROR]"
        case out    = "[OUT]"
    }
    
    static func output(_ str: String) {
        print(str)
        flush()
    }
    
    static func log(
        _ items: Any...,
        separator: String = " ",
        terminator: String = "\n",
        type: LogType = .debug
    ) {
//        if type == .debug { return }
//        if type == .error || type == .warn || type == .info {
        let tag: String = type.rawValue
        let output =
            tag + (tag.count > 0 ? " " : "")
            + items.map { "\($0)" }.joined(separator: separator)
            + terminator
        fputs(output, stderr)
//        }
    }

    static func flush() {
        fflush(stdout)
    }
}
