enum Tester {
    static func isValid(
        size: Int,
        computerTypes: Int,
        fieldInput: [String],
        solver: SolverV1
    ) -> Bool {
        IO.log("startTest:", Time.elapsedTime())
        let field = Field(size: size, computerTypes: computerTypes, fieldInput: fieldInput)
        for move in solver.performedMoves {
            guard field.performMove(move: move) else {
                IO.log("Failed....", type: .error)
                return false
            }
        }
        for connect in solver.connects {
            guard field.performConnect(connect: connect) else {
                IO.log("Failed........", type: .error)
                return false
            }
        }
        IO.log("endTest:", Time.elapsedTime())
        return true
    }
}
