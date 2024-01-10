# DefuckSwift

a copy of some of the interpreters in Java but in Swift

in general BasicInterpreter.java should outperform BasicInterpreter.swift  
CollapsingInterpreter.swift and FlowInterpreter.swift should both outperform their Java variants  
when compiling with `-c release`

the Swift interpreters do have way more noticeable startup for some reason, especially since Java has to start the JVM