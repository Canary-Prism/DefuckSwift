import Darwin

open class FlowInterpreter: CollapsingInterpreter {

    var optimised_code: [OptimisedInstruction] = []

    public override func optimise() {
        super.optimise()


        optimised_code.append(.none)

        for e in collapsed_code {
            let to_add: OptimisedInstruction = switch e {
                case .plus(let amount):
                    .plus(amount)
                case .move(let amount):
                    .move(amount)
                case .out:
                    .out
                case .in:
                    .in
                case .jump(let a, let b):
                    .jump(a, b)
                case .end:
                    .end
            }
            optimised_code.append(to_add)
        }   
        optimised_code.append(.none)

        simplify(from: 1, to: optimised_code.count - 1);
        

        //these comments featuring: totally didn't copy it from the Java codebase

        //let's bind some sets :D
        //this one nukes pluses and sets infront of the set
        for i in (optimised_code.startIndex + 1..<optimised_code.endIndex).reversed() {
            if case .set = optimised_code[i] {
                for v in (code.startIndex..<i).reversed() {
                    if case .set = optimised_code[v] {
                        optimised_code[v] = .none
                    } else if case .plus = optimised_code[v] {
                        optimised_code[v] = .none
                    } else if case .none = optimised_code[v] {
                    } else {
                        break;
                    }
                }
            }
        }
        //this one binds to plusses after and changes its own set value
        for i in optimised_code.startIndex..<optimised_code.endIndex {
            if case .set(let a) = optimised_code[i] {
                var amount = 0;
                for v in i..<code.endIndex {
                    if case .plus(let a) = optimised_code[v] {
                        amount += a;
                        optimised_code[v] = .none
                    } else if case .none = optimised_code[v] {
                    } else {
                        break;
                    }
                }

                optimised_code[i] = .set((a + amount) % 256)
            }
        }
        //if a set 0 happens before a positive jump, nuke the entire loop
        var i = optimised_code.startIndex
        while i < optimised_code.endIndex - 2 {
            if case .set(let a) = optimised_code[i], a == 0 {
                i += 1
                while i < code.endIndex, case .none = optimised_code[i] {
                    i += 1
                }
                guard i < code.endIndex else { break }
                if case .jump(let a, _) = optimised_code[i], a != 0 {
                    for v in i...a {
                        optimised_code[v] = .none
                    }
                }
            }

            i += 1
        }

        //get rid of the nones bc they're really annoying and we don't need them anymore
        compressNone();
    }

    private func simplify(from: Int, to: Int) {

        //if there are loops within this loop they need to be simplified first
        for i in from..<to {
            if case .jump(let a, _) = optimised_code[i], a != 0 {
                simplify(from: i + 1, to: i + a)
            }
        }

        //if there are still loops or IO side-effects then this loop cannot be simplified
        for i in from..<to{
            switch (optimised_code[i]) {
                case .jump, .in, .out, .set, .findzero, .transfer: return
                default: break
            }
        }

        

        //sees if this is a setzero
        var has_moves = false;
        var move_total = 0;
        var has_pluses = false;
        
        for i in from..<to {
            switch (optimised_code[i]) {
                case .move(let amount):
                    has_moves = true;
                    move_total += amount
                
                case .plus:
                    has_pluses = true;
                
                case .jump, .in, .out, .set, .findzero, .transfer: fatalError(BrainfuckInterpreterError.impossibility.description);
                case .none, .end: break
            }
        }

        if (has_moves && has_pluses) {
            if (move_total == 0) {
                var map: [Int: Int] = [:]
                var pointer = 0;
                map[pointer] = 0
                for i in from..<to {
                    let here = optimised_code[i];
                    switch (here) {
                        case .move(let amount):
                            pointer += amount

                            _ = map[pointer] as Any? ?? (map[pointer] = 0)
                        case .plus(let amount):
                            map[pointer]! += amount

                        default: break
                    }
                }
                if (map[0] == -1) {
                    for i in from - 1...to {
                        optimised_code[i] = .none
                    }

                    var v = from - 1;

                    for key in map.keys {
                        if (key != 0 && map[key] != 0) {
                            optimised_code[v] = .transfer(key, map[key]!)
                            v += 1
                        }
                    }

                    optimised_code[v] = .set(0)

                    return;
                }
            }
            return;
        }

        //nuke everything >:D
        for i in from - 1...to {
            optimised_code[i] = .none
        }

        if (!has_moves && has_pluses) {
            optimised_code[from - 1] = .set(0)
        }
        if (!has_pluses && has_moves) {
            optimised_code[from - 1] = .findzero(move_total)
        }
    }

    private func compressNone() {
        var noneless = [OptimisedInstruction]()
        compressNone(&noneless, from: optimised_code.startIndex, to: optimised_code.endIndex);

        optimised_code = noneless;
    }

    private func compressNone(_ noneless: inout [OptimisedInstruction], from: Int, to: Int) {
        var i = from;
        while i < to {
            let here = optimised_code[i];
            switch (here) {
                case .plus, .move, .in, .out, .set, .findzero, .transfer, .end: noneless.append(here)
                case .jump(let d, _):
                    let a = i;
                    let opening = noneless.endIndex;
                    noneless.append(.none)

                    i += d;

                    compressNone(&noneless, from: a + 1, to: i);

                    noneless[opening] = .jump(noneless.endIndex - opening, 0)

                    noneless.append(.jump(0, noneless.endIndex - opening))
                
                case .none: break
            }
            i += 1
        }
    }

    public override func execute(in: UnsafeMutablePointer<FILE>, out: UnsafeMutablePointer<FILE>) throws {
        var memory = [Int](repeating: 0, count: 60_000)
        var pointer = 30_000
        
        var i = optimised_code.startIndex
        while (i < optimised_code.endIndex) {
            let here = optimised_code[i];
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
                case .in: memory[pointer] = Int(fgetc(`in`))
                case .end: return
                case .set(let amount): memory[pointer] = amount
                case .findzero(let step):
                    while (memory[pointer] != 0) {
                        pointer += step
                    }
                case .transfer(let offset, let mul):
                    memory[pointer + offset] = (memory[pointer + offset] + memory[pointer] * mul) & 255;
                case .none:
                    fputs("WARNING! Wasted instruction cycle in FlowInterpreter!", stderr)
                    fflush(stderr)
            }

            i += 1
        }
    }
}

public enum OptimisedInstruction: CustomStringConvertible {
    case plus(Int)
    case move(Int)
    case out
    case `in`
    case jump(Int, Int)
    case end
    case set(Int)
    case findzero(Int)
    case transfer(Int, Int)
    case none

    public var description: String {
        switch (self) {
            case .plus(let amount): " +\(amount)"
            case .move(let amount): " >\(amount)"
            case .out: "."
            case .in: ","
            case .jump(let a, let b): (b == 0) ? " [\(a)": " \(b)]"
            case .end: ";"
            case .set(let n): " =\(n)"
            case .findzero(let step): " ?\(step)"
            case .transfer(let offset, let mul): " ^\(offset)|\(mul)"
            case .none: " _"
        }
    }
}