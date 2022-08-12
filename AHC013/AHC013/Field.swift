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
    let computerTypes: Int
    private(set) var cells: [[Cell]]
    private(set) var computers: [Computer]
    private(set) var computerGroup: [Set<Computer>]
    
    init(size: Int, computerTypes: Int, fieldInput: [String]) {
        self.size = size
        self.computerTypes = computerTypes
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
        self.computerTypes = computerTypes
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
//        IO.log("move:", move.pos, move.pos + move.dir, comp.type, type: .debug)
        moveComputer(comp: comp, to: comp.pos + move.dir)
    }
    
    func performMoves(moves: [Move]) {
        moves.forEach { performMove(move: $0) }
    }
    
    func performConnect(connect: Connect, movedComp: Computer? = nil) {
        let comp1 = connect.comp1, comp2 = connect.comp2
//        IO.log("connect:", comp1.pos, comp2.pos, type: .debug)
                
        guard let dir = Util.toDir(from: comp1.pos, to: comp2.pos) else {
            IO.log("Something went wrong connecting: \(comp1.pos), \(comp2.pos)")
            return
        }

        // Update connect cables
        // FIXME: Does not clean cable when making the cable short
        if let movedComp = movedComp {
            for comp in movedComp.connected {
                guard let dir = Util.toDir(from: movedComp.pos, to: comp.pos) else {
                    IO.log("Something went wrong connecting: \(comp1.pos), \(comp2.pos)")
                    return
                }
                for pos in Util.getBetweenPos(from: movedComp.pos, to: comp.pos) {
                    // check conflict
                    if let cable = cells[pos.y][pos.x].cable,
                       cable.compType != movedComp.type || cable.direction != Util.fromDir(dir: dir) {
                        IO.log("Trying to overwrite cable at: \(pos), \(movedComp.pos), \(comp.pos), may be destructive", type: .warn)
                    }
                    cells[pos.y][pos.x].cable = Cable(
                        compType: movedComp.type,
                        direction: Util.fromDir(dir: dir),
                        comp1: movedComp,
                        comp2: comp
                    )
                }
            }
        }
        
        if let movedComp = movedComp,
           let cable = cell(pos: movedComp.pos).cable,
           cable.compType == movedComp.type {
            // movedComp is moved in a cable
            // update connected information, and remove cable at movedComp.pos
            cable.comp1.connected.remove(cable.comp2)
            cable.comp2.connected.remove(cable.comp1)
            
            cable.comp1.connected.insert(movedComp)
            cable.comp2.connected.insert(movedComp)
            
            movedComp.connected.insert(cable.comp1)
            movedComp.connected.insert(cable.comp2)
            
            cells[movedComp.pos.y][movedComp.pos.x].cable = nil
            
            for pos in Util.getBetweenPos(from: cable.comp1.pos, to: movedComp.pos) {
                cells[pos.y][pos.x].cable = Cable(
                    compType: cable.comp1.type, direction: Util.fromDir(dir: dir),
                    comp1: cable.comp1, comp2: movedComp
                )
            }
            for pos in Util.getBetweenPos(from: movedComp.pos, to: cable.comp2.pos) {
                cells[pos.y][pos.x].cable = Cable(
                    compType: cable.comp2.type, direction: Util.fromDir(dir: dir),
                    comp1: movedComp, comp2: cable.comp2
                )
            }
        }
        else {
            comp1.connected.insert(comp2)
            comp2.connected.insert(comp1)

            for pos in Util.getBetweenPos(from: comp1.pos, to: comp2.pos) {
                cells[pos.y][pos.x].cable = Cable(
                    compType: comp1.type, direction: Util.fromDir(dir: dir),
                    comp1: comp1, comp2: comp2
                )
            }
        }
    }
    
    private func moveComputer(comp: Computer, to: Pos) {
        guard !cell(pos: to).isComputer else {
            IO.log("\(comp.pos) moving to \(to), which is not empty", type: .error)
            dump()
            fatalError()
        }
        cells[to.y][to.x].computer = comp
        cells[comp.pos.y][comp.pos.x].computer = nil
        comp.pos = to
    }
}

extension Field {
    func getCluster(ofComputer comp: Computer) -> Cluster {
        var comps = Set<Computer>()
        comps.insert(comp)
        
        var q = Queue<Computer>()
        q.push(comp)
        
        while let comp = q.pop() {
            for connectedComp in comp.connected {
                guard !comps.contains(connectedComp) else { continue }
                q.push(connectedComp)
                comps.insert(connectedComp)
            }
        }
        
        let cluster = Cluster(comps: comps, types: computerTypes)
        return cluster
    }
    
    func isInSameCluster(comp1: Computer, comp2: Computer) -> Bool {
        let cluster = getCluster(ofComputer: comp1)
        return cluster.comps.contains(comp2)
    }
    
    func findNearestEmptyCell(at: Pos, trialLimit: Int = 50, ignorePos: [Pos] = []) -> Pos? {
        var q = Queue<Pos>()
        var seenPos = Set<Pos>()
        q.push(at)
        seenPos.insert(at)
        for _ in 0 ..< trialLimit {
            guard let v = q.pop() else {
                return nil
            }
            if cell(pos: v).isEmpty && !ignorePos.contains(v) {
                return v
            }
            for dir in Dir.all {
                let nextPos = v + dir
                if nextPos.isValid(boardSize: size) && !seenPos.contains(nextPos) {
                    q.push(nextPos)
                    seenPos.insert(nextPos)
                }
            }
        }
        return nil
    }
    
    func hasConflictedCable(
        at pos: Pos,
        allowedCompType: Int? = nil,
        allowedDirection: Direction? = nil
    ) -> Bool {
        if let cable = cell(pos: pos).cable,
           cable.compType != allowedCompType || cable.direction != allowedDirection {
            return true
        }
        return false
    }
    
    func hasConflictedCable(
        from: Pos,
        to: Pos,
        allowedCompType: Int? = nil,
        allowedDirection: Direction? = nil
    ) -> Bool {
        let path = [from] + Util.getBetweenPos(from: from, to: to) + [to]
        for pos in path {
            if hasConflictedCable(at: pos, allowedCompType: allowedCompType, allowedDirection: allowedDirection) {
                return true
            }
        }
        return false
    }
    
    func getNearComputers(
        aroundComp: Computer,
        loopLimit: Int = 50,
        distF: (Pos, Pos) -> Int
    ) -> [(Int, Computer)] {
        var ret = [(Int, Computer)]()
        
        var q = Queue<Pos>()
        var seenPos = Set<Pos>()
        q.push(aroundComp.pos)
        seenPos.insert(aroundComp.pos)

        for _ in 0 ..< loopLimit {
            guard let v = q.pop() else {
                return ret
            }
            for dir in Dir.all {
                let nextPos = v + dir
                if nextPos.isValid(boardSize: size)
                    && !seenPos.contains(nextPos)
                    && cell(pos: nextPos).computer?.isConnected != true
                    && cell(pos: nextPos).cable == nil {
                    q.push(nextPos)
                    seenPos.insert(nextPos)
                    
                    if let comp = cell(pos: nextPos).computer,
                       aroundComp.type == comp.type {
                        ret.append((distF(aroundComp.pos, comp.pos), comp))
                    }
                }
            }
        }
        
        return ret.sorted(by: { (a, b) in
            return a.0 < b.0
        })
    }
    
    func dump() {
        for i in 0 ..< size {
            for j in 0 ..< size {
                if let comp = cell(pos: Pos(x: j, y: i)).computer {
                    IO.log(comp.type, terminator: "", type: .none)
                }
                else if let _ = cell(pos: Pos(x: j, y: i)).cable {
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
