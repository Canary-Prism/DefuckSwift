// The Swift Programming Language
// https://docs.swift.org/swift-book

import Darwin

open class Interpreter {
    public init(_ code: String) throws {
        self.code = code.compactMap { $0 == ";" ? nil : Instruction(rawValue: $0)}
    }

    var code: [Instruction]

    public func execute(in: UnsafeMutablePointer<FILE>, out: UnsafeMutablePointer<FILE>) throws {
        throw BrainfuckInterpreterError.executeUnimplementedError
    }
}

// because crashing on index out of bounds is dumb
extension Collection {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension StringProtocol {
    subscript(offset: Int) -> Character { self[index(startIndex, offsetBy: offset)] }
    subscript(range: Range<Int>) -> SubSequence {
        let startIndex = index(self.startIndex, offsetBy: range.lowerBound)
        return self[startIndex..<index(startIndex, offsetBy: range.count)]
    }
    subscript(range: ClosedRange<Int>) -> SubSequence {
        let startIndex = index(self.startIndex, offsetBy: range.lowerBound)
        return self[startIndex..<index(startIndex, offsetBy: range.count)]
    }
    subscript(range: PartialRangeFrom<Int>) -> SubSequence { self[index(startIndex, offsetBy: range.lowerBound)...] }
    subscript(range: PartialRangeThrough<Int>) -> SubSequence { self[...index(startIndex, offsetBy: range.upperBound)] }
    subscript(range: PartialRangeUpTo<Int>) -> SubSequence { self[..<index(startIndex, offsetBy: range.upperBound)] }
}

open class OptimisingInterpreter: Interpreter {
    public override init(_ code: String) throws {
        try! super.init(code);
        self.code.append(Instruction.end);

        //balanced loop safety
        //since optimising interpreters would require more preprocessing, this makes validating the code required
        var loop = 0;
        for i in 0..<code.count {
            let e = code[i];
            loop = switch (e) {
                case "[": loop + 1;
                case "]": loop - 1;
                default: loop;
            };
            if (loop < 0) {
                throw BrainfuckInterpreterError.malformedCode(message: """
                        Extra closing loop ']' at position: \(i)
                        \(code[max(i - 5, 0)..<min(i + 5, code.count)])
                             ^
                        """);
            }
        }
        if (loop > 0) {
            throw BrainfuckInterpreterError.malformedCode(message: """
                    \(loop) unterminated loops
                    """);
        }

        optimise();
    }

    public func optimise() {}
}

public enum BrainfuckInterpreterError: Error, CustomStringConvertible {
    case executeUnimplementedError, malformedCode(message: String), impossibility
    public var description: String {
        switch self {
            case .executeUnimplementedError:
                "Interpreter is not an implementation"
            case .malformedCode(let message):
                message
            case .impossibility:
                "Brainfuck Interpreter fatal error. how-?"
        }
    }
}

public enum Instruction: Character {

    case plus = "+"
    case minus = "-"
    case startloop = "["
    case endloop = "]"
    case left = "<"
    case right = ">"
    case out = "."
    //apparently in is a keyword... i forgot :p
    case `in` = ","

    //i need to prevent this from being parsed... see Base.swift:8
    case end = ";"
}