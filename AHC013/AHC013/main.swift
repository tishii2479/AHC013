import Foundation

struct Parameter {
    var distLimit: Int
    var costLimit: Int
    var searchTime: Double
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
    
    // TODO: Optimize
    let param = Parameter(distLimit: 5, costLimit: computerTypes == 2 ? 3 : 5, searchTime: 2.1)
    var solvers = [(Int, Int, SolverV1)]()
    var mainType: Int = 1
    
    while elapsedTime() < param.searchTime {
        let field = Field(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
        let solver = SolverV1(field: field)
        let (score1, cost1) = solver.constructFirstCluster(type: mainType, param: param)
        IO.log("a:", score1, cost1, mainType, elapsedTime())
        
        let (score2, cost2) = solver.constructSecondCluster(param: param)
        solvers.append((score2, cost2, solver))
        IO.log("b:", score2, cost2, elapsedTime())
        
        mainType += 1
        if mainType > computerTypes {
            mainType = 1
        }
    }
    
    solvers.sort(by: { (a, b) in
        if a.0 != b.0 { return a.0 > b.0 }
        return a.1 < b.1
    })
    
    IO.log(solvers.map{ $0.0 })
    
    guard let bestSolver = solvers.first?.2 else {
        return
    }

    let _ = bestSolver.constructOtherClusters(param: param)

    output(
        moves: bestSolver.performedMoves,
        connects: Array(bestSolver.connects),
        commandLimit: computerTypes * 100
    )
    
    IO.log("Score:", bestSolver.field.calcScore())
    IO.log("Runtime:", elapsedTime())
}

main()
