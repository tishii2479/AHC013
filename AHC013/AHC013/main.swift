import Foundation

struct Parameter {
    var distLimit: Int
    var costLimit: Int
    var searchTime: Double
    
    func semiBuffed(_ x: Int) -> Int {
        x * 3 / 2
    }
    
    func buffed(_ x: Int) -> Int {
        x * 2
    }
    
    init(n: Int, k: Int) {
        self.searchTime = 2.5
        
        if k == 2 {
            distLimit = n / 4
        }
        else {
            distLimit = n / 5
        }
        
        if k <= 3 {
            costLimit = 3
        }
        else {
            costLimit = 5
        }
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

    IO.log("Moves:", moveCount, "Connects:", connectCount)
}

func main() {
    let a = IO.readIntArray()
    let fieldSize = a[0], computerTypes = a[1]
    var fieldInput = [String](repeating: "", count: fieldSize)
    for i in 0 ..< fieldSize {
        fieldInput[i] = IO.readString()
    }
    
    let param = Parameter(n: fieldSize, k: computerTypes)
    var solvers = [(Int, Int, SolverV1)]()
    var mainType: Int = 1

    Time.timeLimit = param.searchTime
    
    let field = Field(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
    let nearCompPair = field.getNearCompPair(
        types: Array(1 ... computerTypes), distF: Util.distF,
        distLimit: field.size / 2, maxSize: 10)

    while Time.elapsedTime() < param.searchTime {
        let field = Field(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
        let solver = SolverV1(field: field, nearCompPair: nearCompPair)
        
        let (score1, _) = solver.constructFirstCluster(type: mainType, param: param)
        IO.log("a:", solver.currentCommands, score1, Time.elapsedTime())
        
        let (score2, _) = solver.constructSecondCluster(param: param)
        IO.log("b:", solver.currentCommands, score2, Time.elapsedTime())
        
        let (score3, cost3) = solver.constructSecondCluster(param: param)
        IO.log("d:", solver.currentCommands, score3, Time.elapsedTime())

        solvers.append((score3, cost3, solver))
        
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
    
    guard let bestSolver = solvers.first(where: {
        Tester.isValid(
            size: fieldSize, computerTypes: computerTypes,
            fieldInput: fieldInput, solver: $0.2)
    })?.2 else {
        return
    }
    
    Time.timeLimit = 2.8

    let _ = bestSolver.constructOtherClusters(param: param)
    
    // double check
    if Tester.isValid(
        size: fieldSize, computerTypes: computerTypes,
        fieldInput: fieldInput, solver: bestSolver) {
        output(solver: bestSolver, commandLimit: computerTypes * 100)
    }
    else {
        solvers.removeFirst()
        guard let bestSolver = solvers.first(where: {
            Tester.isValid(
                size: fieldSize, computerTypes: computerTypes,
                fieldInput: fieldInput, solver: $0.2)
        })?.2 else {
            return
        }
        output(solver: bestSolver, commandLimit: computerTypes * 100)
    }
    
    IO.log("Score:", bestSolver.field.calcScore())
    IO.log("Runtime:", Time.elapsedTime())
}

main()
