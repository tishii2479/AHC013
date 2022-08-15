import Foundation

struct Parameter {
    var distLimit: Int
    var costLimit: Int
    var searchTime: Double
}

func output(solver: SolverV1, commandLimit: Int) {
    let moves = solver.performedMoves
    let connects = Array(solver.connects)
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
    let param = Parameter(
        distLimit: fieldSize / 5,
        costLimit: computerTypes == 2 ? 3 : 5,
        searchTime: 2.2
    )
    var solvers = [(Int, Int, SolverV1)]()
    var mainType: Int = 1

    Time.timeLimit = param.searchTime

    while Time.elapsedTime() < param.searchTime {
        let field = Field(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
        let solver = SolverV1(field: field)
        let (score1, cost1) = solver.constructFirstCluster(type: mainType, param: param)
        IO.log("a:", score1, cost1, mainType, Time.elapsedTime(), type: .log)
        
//        output(solver: solver, commandLimit: computerTypes * 100)
        let _ = solver.constructSecondCluster(param: param)
        let _ = solver.constructSecondCluster(param: param)
        let (score2, cost2) = solver.constructSecondCluster(param: param)
        solvers.append((score2, cost2, solver))
        IO.log("b:", score2, cost2, Time.elapsedTime(), type: .log)
//        output(solver: solver, commandLimit: computerTypes * 100)
        
        mainType += 1
        if mainType > computerTypes {
            mainType = 1
        }
    }
    
    IO.log("c:", Time.elapsedTime())

    solvers.sort(by: { (a, b) in
        if a.0 != b.0 { return a.0 > b.0 }
        return a.1 < b.1
    })
    
    IO.log(solvers.map{ $0.0 })
    
    guard let bestSolver = solvers.first?.2 else {
        return
    }
    
    Time.timeLimit = 2.8

    let _ = bestSolver.constructOtherClusters(param: param)
    
    output(solver: bestSolver, commandLimit: computerTypes * 100)
    
    IO.log("Score:", bestSolver.field.calcScore())
    IO.log("Runtime:", Time.elapsedTime())
}

main()
