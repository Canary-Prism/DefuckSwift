import Foundation
import Darwin
import Defuck

// because crashing on index out of bounds is dumb
extension Collection {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

guard let location = CommandLine.arguments[safe: 1] else { 
    fatalError("arg0: specify a file path for the code") 
}

guard let code_file = fopen(location, "r") else {
    fatalError("arg0: code file not found")
}

//i totally didn't steal this from mimi
var fileSize: size_t = 0
var size: size_t = 0;
fseek(code_file, 0, SEEK_END);
size = ftell(code_file);
rewind(code_file);
var charptr = UnsafeMutablePointer<CChar>.allocate(capacity: size)
fileSize = fread(charptr, MemoryLayout<CChar>.stride, size, code_file);

//cheap hack to skip nulls bc null terminated cstr :p
var cstr = [CChar]()
for i in 0..<fileSize {
    guard charptr.advanced(by: i).pointee != 0 else { continue }
    cstr.append(charptr.advanced(by: i).pointee)
}
//can't believe i made a hack to fix null terminated strings and forgot to terminate the null terminated string with a null
cstr.append(0)

var code = String(cString: cstr)

guard let interpreter_code = CommandLine.arguments[safe: 2] else {
    fatalError("arg1: specify an interpreter")
}

do {

    let interpreter: Interpreter = switch (interpreter_code) {
        case "-b":
            BasicInterpreter(code)
        case "-c":
            try CollapsingInterpreter(code)
        case "-f":
            try FlowInterpreter(code)
        default:
            fatalError("Invalid interpreter type")
    }


    try interpreter.execute(in: stdin, out: stdout)
} catch {
    print(error.localizedDescription)
    exit(-1)
}
fflush(stdout)