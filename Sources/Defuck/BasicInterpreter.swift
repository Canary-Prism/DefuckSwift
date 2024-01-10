import Darwin

open class BasicInterpreter: Interpreter {

    public override init(_ code: String) {
        try! super.init(code);
    }

    public override func execute(in: UnsafeMutablePointer<FILE>, out: UnsafeMutablePointer<FILE>) {
        var memory = [UInt8](repeating: 0, count: 60_000)
        var pointer = 30_000

        var i = code.startIndex
        while i < code.endIndex {
            switch (code[i]) {
                case .plus:
                    memory[pointer] &+= 1
                case .minus:
                    memory[pointer] &-= 1
                case .startloop:
                    if (memory[pointer] == 0) {
                        var loops = 1;
                        while (loops > 0) {
                            i += 1
                            if (code[i] == .startloop) {
                                loops += 1
                            } else if (code[i] == .endloop) {
                                loops -= 1
                            }
                        }
                    }
                case .endloop:
                    if (memory[pointer] != 0) {
                        var loops = 1;
                        while (loops > 0) {
                            i -= 1
                            if (code[i] == .endloop) {
                                loops += 1
                            } else if (code[i] == .startloop) {
                                loops -= 1
                            }
                        }
                    }
                case .left:
                    pointer -= 1
                case .right:
                    pointer += 1
                case .out:
                    fputc(Int32(memory[pointer]), out)
                case .in:
                    memory[pointer] = UInt8(exactly: fgetc(`in`) & 255)!
                case .end:
                    return
            }


            i += 1
        }
    }
}