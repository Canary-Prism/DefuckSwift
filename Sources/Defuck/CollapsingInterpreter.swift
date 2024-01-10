import Darwin

open class CollapsingInterpreter: OptimisingInterpreter {
    
    var collapsed_code: [CollapsedInstruction] = []

    public override func optimise() {
        optimise(from: code.startIndex, to: code.endIndex)
    }

    public func optimise(from: Int, to: Int) {
        var i = from
        while (i < to) {
            switch (code[i]) {
                case .plus, .minus: 
                    var amount = 0;
                    while (i < code.endIndex && (code[i] == .plus || code[i] == .minus)) {
                        amount += (code[i] == .plus) ? 1 : -1;
                        i += 1
                    }
                    if (amount % 256 != 0) {
                        collapsed_code.append(.plus(amount % 256))
                    }

                    i -= 1
                
                case .left, .right:
                    var amount = 0;
                    while (code[i] == .right || code[i] == .left) {
                        amount += (code[i] == .right) ? 1 : -1;
                        i += 1
                    }

                    
                    if (amount != 0) {
                        collapsed_code.append(.move(amount))
                    }

                    i -= 1;

                case .startloop:
                    let a = i;
                    let opening = collapsed_code.endIndex;
                    collapsed_code.append(.end)

                    var loops = 1;
                    while (loops > 0) {
                        i += 1;
                        if (code[i] == .startloop) {
                            loops += 1;
                        } else if (code[i] == .endloop) {
                            loops -= 1;
                        }
                    }

                    optimise(from: a + 1, to: i);

                    collapsed_code[opening] = .jump(collapsed_code.endIndex - opening, 0)

                    collapsed_code.append(.jump(0, collapsed_code.endIndex - opening))
                

                case .out: collapsed_code.append(.out)
                case .in:
                    if case .plus = collapsed_code.last {
                        collapsed_code.removeLast();
                    }
                    collapsed_code.append(.in)

                case .endloop: break
                case .end: collapsed_code.append(.end)
            }
            i += 1
        }
    }

    public override func execute(in: UnsafeMutablePointer<FILE>, out: UnsafeMutablePointer<FILE>) throws {
        var memory = [Int](repeating: 0, count: 60_000)
        var pointer = 30_000

        var i = collapsed_code.startIndex
        while (i < collapsed_code.endIndex) {
            let here = collapsed_code[i];
            switch (here) {
                case .plus(let amount): memory[pointer] = (memory[pointer] + amount) & 255
                case .jump(let a, let b): 
                    if (memory[pointer] == 0) {
                        i += a;
                    } else {
                        i -= b
                    }
                
                case .move(let amount): pointer += amount;
                case .out: fputc(Int32(memory[pointer]), out)
                case .in: memory[pointer] = Int(fgetc(`in`) & 255)
                case .end: return
            }

            i += 1
        }
    }
}
public enum CollapsedInstruction: CustomStringConvertible {
    case plus(Int)
    case move(Int)
    case out
    case `in`
    case jump(Int, Int)
    case end

    public var description: String {
        switch (self) {
            case .plus(let amount): " +\(amount)"
            case .move(let amount): " >\(amount)"
            case .out: "."
            case .in: ","
            case .jump(let a, let b): (b == 0) ? " [\(a)": " \(b)]"
            case .end: ";"
        }
    }
}