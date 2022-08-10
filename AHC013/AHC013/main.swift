func main() {
    let a = IO.readIntArray()
    let fieldSize = a[0], _ = a[1]
    
    let field = Field(size: fieldSize)
    var fieldInput = [String](repeating: "", count: fieldSize)
    for i in 0 ..< fieldSize {
        fieldInput[i] = IO.readString()
    }
    field.parseField(strs: fieldInput)
    
    let solver = SolverV1(field: field)
    solver.solve()
}

main()
