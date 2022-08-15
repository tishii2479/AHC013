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
    private var clusters: [Cluster]
    private let uf: UnionFind
    
    init(
        size: Int,
        computerTypes: Int,
        cells: [[Cell]],
        computers: [Computer],
        computerGroup: [Set<Computer>]
    ) {
        self.size = size
        self.computerTypes = computerTypes
        self.cells = cells
        self.computers = computers
        self.computerGroup = computerGroup
        self.clusters = [Cluster](
            repeating: Cluster(comps: [], types: computerTypes),
            count: computerTypes * 100)
        for i in 0 ..< computerTypes * 100 {
            self.clusters[i].add(comp: computers[i])
        }
        self.uf = UnionFind(n: computerTypes * 100)
    }
    
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
        self.clusters = [Cluster](
            repeating: Cluster(comps: [], types: computerTypes),
            count: computerTypes * 100)
        self.uf = UnionFind(n: computerTypes * 100)
        
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
        for i in 0 ..< computerTypes * 100 {
            self.clusters[i].add(comp: computers[i])
        }
    }
        
    func cell(pos: Pos) -> Cell {
        cells[pos.y][pos.x]
    }
    
    func reverseMoves(moves: [Move]) {
        for move in moves.reversed() {
            performMove(
                move: Move(pos: move.pos + move.dir, dir: move.dir.rev),
                isTemporary: true
            )
        }
    }
    
    func performMove(move: Move, isTemporary: Bool = false) {
        guard let comp = cell(pos: move.pos).computer else {
            IO.log("Could not find computer at: \(move.pos)", type: .error)
            dump()
            fatalError()
        }
        if !isTemporary,
           let connectedComp = comp.connectedComp(to: move.dir.rev) {
            // extend cable
            cells[comp.pos.y][comp.pos.x].cable = Cable(
                compType: comp.type, direction: Util.fromDir(dir: move.dir),
                comp1: comp, comp2: connectedComp
            )
        }
        if !isTemporary,
           let cable = cell(pos: comp.pos + move.dir).cable,
           cable.comp1 == comp || cable.comp2 == comp {
            // reset cable
            cells[(comp.pos + move.dir).y][(comp.pos + move.dir).x].cable = nil
        }
//        IO.log("move:", move.pos, move.pos + move.dir, comp.type, type: .debug)
        moveComputer(comp: comp, to: comp.pos + move.dir)
    }
    
    func performMoves(moves: [Move]) {
        moves.forEach { performMove(move: $0) }
    }
    
    func resetConnect(connect: Connect) {
        connect.comp1.connected.remove(connect.comp2)
        connect.comp2.connected.remove(connect.comp1)
        for pos in Util.getBetweenPos(from: connect.comp1.pos, to: connect.comp2.pos) {
            cells[pos.y][pos.x].cable = nil
        }
    }
    
    func performConnect(
        connect: Connect, movedComp: Computer? = nil,
        isTemporary: Bool = false
    ) {
        let comp1 = connect.comp1, comp2 = connect.comp2
        // just in case, perform both...
        clusters[uf.root(of: comp1.id)].merge(clusters[uf.root(of: comp2.id)])
        clusters[uf.root(of: comp2.id)].merge(clusters[uf.root(of: comp1.id)])
        uf.merge(comp1.id, comp2.id)
//        IO.log("connect:", comp1.pos, comp2.pos, type: .debug)
                
        guard let dir = Util.toDir(from: comp1.pos, to: comp2.pos) else {
            IO.log("Something went wrong connecting: \(comp1.pos), \(comp2.pos)")
            return
        }

        // Update connect cables
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
                guard !cell(pos: pos).isComputer else {
                    IO.log("\(pos) is not empty to place cables", type: .error)
                    dump()
                    fatalError()
                }
                cells[pos.y][pos.x].cable = Cable(
                    compType: cable.comp1.type, direction: Util.fromDir(dir: dir),
                    comp1: cable.comp1, comp2: movedComp
                )
            }
            for pos in Util.getBetweenPos(from: movedComp.pos, to: cable.comp2.pos) {
                guard !cell(pos: pos).isComputer else {
                    IO.log("\(pos) is not empty to place cables", type: .error)
                    dump()
                    fatalError()
                }
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
                guard !cell(pos: pos).isComputer else {
                    IO.log("\(pos) is not empty to place cables", type: .error)
                    dump()
                    fatalError()
                }
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
    func getPreciseCluster(ofComputer comp: Computer) -> Cluster {
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
    
    func getCluster(ofComputer comp: Computer) -> Cluster {
        clusters[uf.root(of: comp.id)]
    }
    
    func isInSameCluster(comp1: Computer, comp2: Computer) -> Bool {
        uf.same(comp1.id, comp2.id)
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
        distLimit: Int = 20,
        distF: (Pos, Pos) -> Int,
        maxSize: Int = 100
    ) -> [(Int, Computer)] {
        var ret = [(Int, Computer)]()
        
        var q = Queue<Pos>()
        var seenPos = Set<Pos>()
        q.push(aroundComp.pos)
        seenPos.insert(aroundComp.pos)

        for _ in 0 ..< loopLimit {
            guard let v = q.pop() else {
                break
            }
            for dir in Dir.all {
                guard ret.count <= maxSize else {
                    break
                }
                let nextPos = v + dir
                if nextPos.isValid(boardSize: size)
                    && distF(aroundComp.pos, nextPos) <= distLimit
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
    
    // TODO: add test
    func movable(comp: Computer, moveLimit: Int = 10) -> [Pos] {
        var ret: [Pos] = [comp.pos]
        for dir in Dir.all {
            var cPos = comp.pos
            guard comp.isMovable(dir: dir) else { continue }
            
            for _ in 0 ..< moveLimit {
                let nextPos = cPos + dir
                guard nextPos.isValid(boardSize: size),
                      cell(pos: cPos + dir).isEmpty else {
                    continue
                }
                ret.append(cPos + dir)
                cPos += dir
            }
        }
        return ret
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
    
    func calcScore() -> Int {
        var score = 0
        var seen = Set<Computer>()
        for comp in computers {
            guard !seen.contains(comp) else { continue }
            let cluster = getCluster(ofComputer: comp)
            score += cluster.calcScore()
            seen.formUnion(cluster.comps)
        }
        return score
    }
    
    func copy() -> Field {
        var computerDicts: [Computer: Computer] = [:]
        for comp in computers {
            computerDicts[comp] = Computer(id: comp.id, type: comp.type, pos: comp.pos)
        }
        for (oldComp, newComp) in computerDicts {
            for comp in oldComp.connected {
                guard let comp = computerDicts[comp] else {
                    IO.log("Failed to copy field", type: .error)
                    break
                }
                newComp.connected.insert(comp)
            }
        }
        let newComputers = Array(computerDicts.values)
        var newCells = cells
        for i in 0 ..< size {
            for j in 0 ..< size {
                if let comp = newCells[i][j].computer {
                    newCells[i][j].computer = computerDicts[comp]
                }
                if let cable = newCells[i][j].cable,
                   let comp1 = computerDicts[cable.comp1],
                   let comp2 = computerDicts[cable.comp1] {
                    newCells[i][j].cable = Cable(
                        compType: cable.compType, direction: cable.direction,
                        comp1: comp1,
                        comp2: comp2
                    )
                }
            }
        }
        var newComputerGroups = computerGroup
        for i in 1 ... computerTypes {
            newComputerGroups[i] = Set(
                newComputerGroups[i].map {
                    computerDicts[$0]!
                }
            )
        }
        
        return Field(
            size: size, computerTypes: computerTypes, cells: newCells,
            computers: newComputers, computerGroup: newComputerGroups
        )
    }
}
