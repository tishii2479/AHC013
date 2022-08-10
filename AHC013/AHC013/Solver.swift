protocol Solver {
    init(field: Field)
    func solve()
}

class SolverV1 {
    private let field: Field

    init(field: Field) {
        self.field = field
    }

    func solve() {
        
    }
    
    func searchMove() {
        guard let comp = field.computers.randomElement() else {
            IO.log("Something wrong at field.computers", type: .warn)
            return
        }
    }
}
