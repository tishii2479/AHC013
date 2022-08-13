import Foundation

struct Parameter {
    var distLimit: Int
    var costLimit: Int
}

func output(moves: [Move], connects: [Connect], commandLimit: Int) {
    let moveCount = min(moves.count, commandLimit)
    let connectCount = min(connects.count, max(0, commandLimit - moveCount))

    IO.output("\(moveCount)")
    for i in 0 ..< moveCount {
        IO.output(moves[i].outValue)
    }
    IO.output("\(connectCount)")
    for i in 0 ..< connectCount {
        IO.output(connects[i].outValue)
    }
    
    guard moveCount + connectCount > 0 else {
        IO.log("moves and connects are empty..", type: .error)
        return
    }

    for i in 1 ... moveCount + connectCount {
        IO.output("\(min(i, moveCount))")
        for j in 0 ..< min(i, moveCount) {
            IO.output(moves[j].outValue)
        }
        IO.output("\(max(0, i - moveCount))")
        if i <= moveCount { continue }
        for j in 0 ..< i - moveCount {
            IO.output(connects[j].outValue)
        }
    }
        
    IO.log("Moves:", moveCount, "Connects:", connectCount)
}

func main() {
    let a = IO.readIntArray()
    let fieldSize = a[0], computerTypes = a[1]
    var fieldInput = [String](repeating: "", count: fieldSize)
    for i in 0 ..< fieldSize {
        fieldInput[i] = IO.readString()
    }
    let field = FieldV2(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
    
    let solver = SolverV2(field: field)
    
    // TODO: Optimize
    let param = Parameter(distLimit: 5, costLimit: computerTypes == 2 ? 3 : 5)
    let (moves, connects) = solver.solve(param: param)
    
    output(moves: moves, connects: connects, commandLimit: computerTypes * 100)
    
    IO.log("Score:", field.calcScore())
    IO.log("Runtime:", elapsedTime())
}

main()
