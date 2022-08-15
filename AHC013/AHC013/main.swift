import Foundation

struct Parameter {
    var d1: Int
    var d2: Int
    var d3: Int
    var c1: Int
    var c2: Int
    var c3: Int
    
    init(n: Int, k: Int) {
        d1 = 5
        c1 = 3
        d2 = 5
        c2 = 3
        d3 = 5
        c3 = 3
    }
    
    init(
        d1: Int,
        d2: Int,
        d3: Int,
        c1: Int,
        c2: Int,
        c3: Int
    ) {
        self.d1 = d1
        self.d2 = d2
        self.d3 = d3
        self.c1 = c1
        self.c2 = c2
        self.c3 = c3
    }
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

    // TODO: Remove when submission
//    guard moveCount + connectCount > 0 else {
//        IO.log("moves and connects are empty..", type: .error)
//        return
//    }
//    for i in 1 ... moveCount + connectCount {
//        IO.output("\(min(i, moveCount))")
//        for j in 0 ..< min(i, moveCount) {
//            IO.output(moves[j].outValue)
//        }
//        IO.output("\(max(0, i - moveCount))")
//        if i <= moveCount { continue }
//        for j in 0 ..< i - moveCount {
//            IO.output(connects[j].outValue)
//        }
//    }

    IO.log("Moves:", moveCount, "Connects:", connectCount)
}

func main() {
    let a = IO.readIntArray()
    let fieldSize = a[0], computerTypes = a[1]
    var fieldInput = [String](repeating: "", count: fieldSize)
    for i in 0 ..< fieldSize {
        fieldInput[i] = IO.readString()
    }
    
    var solvers = [(Int, Int, SolverV1)]()
    var mainType: Int = 1
    
    let searchTime = 2.3

    Time.timeLimit = searchTime

    while Time.elapsedTime() < searchTime {
        let field = Field(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
        let solver = SolverV1(field: field, param: param)
        let (score1, cost1) = solver.constructFirstCluster(type: mainType)
        IO.log("a:", score1, cost1, mainType, Time.elapsedTime(), type: .log)
        
//        output(solver: solver, commandLimit: computerTypes * 100)
        let _ = solver.constructSecondCluster()
        let _ = solver.constructSecondCluster()
        let (score2, cost2) = solver.constructSecondCluster()
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

    let _ = bestSolver.constructOtherClusters()
    
    output(solver: bestSolver, commandLimit: computerTypes * 100)
    
    IO.log("Score:", bestSolver.field.calcScore())
    IO.log("Runtime:", Time.elapsedTime())
}

main()
