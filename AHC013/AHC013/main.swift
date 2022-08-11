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
    
    IO.output("\(moves.count)")
    for move in moves {
        IO.output(move.outValue)
    }
    IO.output("\(connects.count)")
    for connect in connects {
        IO.output(connect.outValue)
    }
    
//    for i in 1 ... moves.count + connects.count {
//        IO.output("\(min(i, moves.count))")
//        for j in 0 ..< min(i, moves.count) {
//            IO.output(moves[j].outValue)
//        }
//        IO.output("\(max(0, i - moves.count)")
//        if i <= moves.count { continue }
//        for j in 0 ..< i - moves.count {
//            IO.output(connects[j].outValue)
//        }
//    }
}

main()
