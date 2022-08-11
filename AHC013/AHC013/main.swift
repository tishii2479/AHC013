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
}

main()
