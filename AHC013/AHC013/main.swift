func main() {
    let a = IO.readIntArray()
    let fieldSize = a[0], computerTypes = a[1]
    var fieldInput = [String](repeating: "", count: fieldSize)
    for i in 0 ..< fieldSize {
        fieldInput[i] = IO.readString()
    }
    let field = Field(size: fieldSize, computerTypes: computerTypes, fieldInput: fieldInput)
    
    let solver = SolverV1(field: field)
    let (moves, connects) = solver.solve()
    
    let moveCount = min(moves.count, computerTypes * 100)
    let connectCount = min(connects.count, max(0, computerTypes * 100 - moveCount))
    
    IO.output("\(moveCount)")
    for i in 0 ..< moveCount {
        IO.output(moves[i].outValue)
    }
    IO.output("\(connectCount)")
    for i in 0 ..< connectCount {
        IO.output(connects[i].outValue)
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
}

main()
