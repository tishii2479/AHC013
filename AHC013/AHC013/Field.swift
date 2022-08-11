class Field {
    struct Cell {
        var computer: Computer?
        var cable: Cable?
        
        var isComputer: Bool {
            computer != nil
        }
        var isCabled: Bool {
            cable != nil
        }
        var isEmpty: Bool {
            !isComputer && !isCabled
        }
    }
    
    let size: Int
    private(set) var cells: [[Cell]]
    private(set) var computers: [Computer]
    private(set) var computerGroup: [Set<Computer>]
    
    init(size: Int, computerTypes: Int, fieldInput: [String]) {
        self.size = size
        self.computers = []
        self.cells = [[Cell]](
            repeating: [Cell](
                repeating: Cell(computer: nil, cable: nil),
                count: size
            ),
            count: size
        )
        self.computerGroup = [Set<Computer>](
            repeating: Set<Computer>(),
            count: computerTypes + 1
        )
        
        for i in 0 ..< size {
            for j in 0 ..< size {
                let row = fieldInput[i]
                guard let type = row[row.index(row.startIndex, offsetBy: j)].wholeNumberValue else {
                    fatalError("Failed to read field from input")
                }
                
                if type > 0 {
                    let comp = Computer(id: computers.count, type: type, pos: Pos(x: j, y: i))
                    cells[i][j] = Cell(computer: comp, cable: nil)
                    computers.append(comp)
                    computerGroup[comp.type].insert(comp)
                }
            }
        }
    }
    
    init(size: Int, computerTypes: Int, cells: [[Cell]]) {
        self.size = size
        self.cells = cells
        self.computers = []
        self.computerGroup = [Set<Computer>](
            repeating: Set<Computer>(),
            count: computerTypes + 1
        )
        
        for i in 0 ..< size {
            for j in 0 ..< size {
                if let comp = cells[i][j].computer {
                    computerGroup[comp.type].insert(comp)
                    computers.append(comp)
                }
            }
        }
    }
        
    func cell(pos: Pos) -> Cell {
        cells[pos.y][pos.x]
    }
    
    func reverseMoves(moves: [Move]) {
        for move in moves.reversed() {
            performMove(move: Move(pos: move.pos + move.dir, dir: move.dir.rev))
        }
    }
    
    func performMove(move: Move) {
        guard let comp = cell(pos: move.pos).computer else {
            IO.log("Could not find computer at: \(move.pos)", type: .error)
            dump()
            fatalError()
        }
        IO.log("move:", move.pos, move.pos + move.dir, comp.type, type: .debug)
        moveComputer(comp: comp, to: comp.pos + move.dir)
    }
    
    func performMoves(moves: [Move]) {
        moves.forEach { performMove(move: $0) }
    }
    
    func performConnect(connect: Connect) {
        let comp1 = connect.comp1, comp2 = connect.comp2
        IO.log("connect:", comp1.pos, comp2.pos, type: .debug)
        comp1.connected.append(comp2)
        comp2.connected.append(comp1)
        
        for pos in Util.getBetweenPos(from: comp1.pos, to: comp2.pos) {
            guard let dir = Util.toDir(from: comp1.pos, to: comp2.pos) else {
                IO.log("Something went wrong connecting: \(comp1.pos), \(comp2.pos)")
                return
            }
            cells[pos.y][pos.x].cable = Cable(compType: comp1.type, direction: Util.fromDir(dir: dir))
        }
    }
    
    private func moveComputer(comp: Computer, to: Pos) {
        guard !cell(pos: to).isComputer else {
            IO.log("\(to) is not empty", type: .error)
            dump()
            fatalError()
        }
        cells[to.y][to.x].computer = comp
        cells[comp.pos.y][comp.pos.x].computer = nil
        comp.pos = to
    }
}

extension Field {
    func getCluster(ofComputer comp: Computer, ignoreComp: Computer? = nil) -> Set<Computer> {
        var cluster = Set<Computer>()
        cluster.insert(comp)
        
        var q = Queue<Computer>()
        q.push(comp)
        
        while let comp = q.pop() {
            for connectedComp in comp.connected {
                guard !cluster.contains(connectedComp),
                      ignoreComp != connectedComp else { continue }
                q.push(connectedComp)
                cluster.insert(connectedComp)
            }
        }
        
        return cluster
    }
    
    func isInSameCluster(comp1: Computer, comp2: Computer) -> Bool {
        let cluster = getCluster(ofComputer: comp1)
        return cluster.contains(comp2)
    }
    
    func findNearestEmptyCell(pos: Pos, trialLimit: Int = 20, ignorePos: [Pos] = []) -> Pos? {
        var q = Queue<Pos>()
        q.push(pos)
        for _ in 0 ..< trialLimit {
            guard let v = q.pop() else {
                return nil
            }
            if cell(pos: v).isEmpty && !ignorePos.contains(v) {
                return v
            }
            for dir in Dir.all {
                let nextPos = pos + dir
                if nextPos.isValid(boardSize: size) {
                    q.push(nextPos)
                }
            }
        }
        return nil
    }
    
    func hasCable(
        from: Pos,
        to: Pos,
        allowedCable: Cable? = nil
    ) -> Bool {
        let path = [from] + Util.getBetweenPos(from: from, to: to) + [to]
        for pos in path {
//            if let cable = cell(pos: pos).cable,
//               let allowedCable = allowedCable,
//               cable != allowedCable {
            if let cable = cell(pos: pos).cable {
                return true
            }
        }
        return false
    }
    
    func dump() {
        for i in 0 ..< size {
            for j in 0 ..< size {
                if let comp = cell(pos: Pos(x: j, y: i)).computer {
                    IO.log(comp.type, terminator: "", type: .none)
                }
                else if let cable = cell(pos: Pos(x: j, y: i)).cable {
                    IO.log("-", terminator: "", type: .none)
                }
                else {
                    IO.log(0, terminator: "", type: .none)
                }
            }
            IO.log("", type: .none)
        }
    }
}
