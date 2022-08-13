class FieldV2 {
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
}

extension FieldV2 {
    func canPerformConnect(comp1: Computer, comp2: Computer) -> Bool {
        guard Util.isAligned(comp1.pos, comp2.pos) else {
            return false
        }
        if comp1.isConnected(to: comp2) || comp2.isConnected(to: comp1) {
            return false
        }
        for pos in Util.getBetweenPos(from: comp1.pos, to: comp2.pos) {
            guard cell(pos: pos).isEmpty else {
                return false
            }
        }
        return true
    }
    
    func performConnect(comp1: Computer, comp2: Computer) {
        guard let direction = Util.direction(from: comp1.pos, to: comp2.pos) else {
            IO.log("Could not connect between \(comp1.pos), \(comp2.pos)", type: .error)
            return
        }
        for pos in Util.getBetweenPos(from: comp1.pos, to: comp2.pos) {
            cells[pos.y][pos.x].cable = Cable(
                compType: comp1.type, direction: direction, comp1: comp1, comp2: comp2
            )
        }
        comp1.connected.insert(comp2)
        comp2.connected.insert(comp1)
    }
    
    func eraseConnect(comp1: Computer, comp2: Computer) {
        guard comp1.isConnected(to: comp2) && comp2.isConnected(to: comp1) else {
            IO.log("Connection does not exist between \(comp1.pos), \(comp2.pos)", type: .error)
            return
        }
        for pos in Util.getBetweenPos(from: comp1.pos, to: comp2.pos) {
            cells[pos.y][pos.x].cable = nil
        }
        comp1.connected.remove(comp2)
        comp2.connected.remove(comp1)
    }
    
    func canMoveComputer(to pos: Pos, compType: Int) -> Bool {
        !hasConflictedCable(at: pos, allowedCompType: compType) && !cell(pos: pos).isComputer
    }
    
    func canPerformMoveSet(moveSet: MoveSet) -> Bool {
        if let cable = cell(pos: moveSet.to).cable,
           cable.compType != moveSet.comp.type {
            return false
        }
        for pos in moveSet.path() {
            if cell(pos: pos).isComputer {
                return false
            }
        }
        for move in moveSet.moves {
            if !move.comp.isMovable(dir: move.dir) {
                return false
            }
        }
        return true
    }

    func performMoveSet(moveSet: MoveSet) {
        for (d1, d2) in [(Dir.left, Dir.right), (Dir.up, Dir.down)] {
            if let comp1 = moveSet.comp.connectedComp(to: d1),
               let comp2 = moveSet.comp.connectedComp(to: d2) {
                eraseConnect(comp1: moveSet.comp, comp2: comp1)
                eraseConnect(comp1: moveSet.comp, comp2: comp2)
                performConnect(comp1: comp1, comp2: comp2)
            }
        }
        for move in moveSet.moves {
            performMove(move: move)
        }
        if let cable = cell(pos: moveSet.comp.pos).cable {
            eraseConnect(comp1: cable.comp1, comp2: cable.comp2)
            performConnect(comp1: moveSet.comp, comp2: cable.comp1)
            performConnect(comp1: moveSet.comp, comp2: cable.comp2)
        }
    }

    func reverseMoveSet(moveSet: MoveSet) {
        performMoveSet(moveSet: moveSet.rev())
    }

    private func performMove(move: MoveV2) {
        if let connectedComp = move.comp.connectedComp(to: move.dir.rev) {
            cells[move.comp.pos.y][move.comp.pos.x].cable = Cable(
                compType: move.comp.type, direction: Util.fromDir(dir: move.dir),
                comp1: move.comp, comp2: connectedComp
            )
        }
        
        if let cable = cell(pos: move.nextPos).cable,
           cable.comp1 == move.comp || cable.comp2 == move.comp {
            cells[move.nextPos.y][move.nextPos.x].cable = nil
        }
        
        cells[move.nextPos.y][move.nextPos.x].computer = move.comp
        cells[move.comp.pos.y][move.comp.pos.x].computer = nil
        move.comp.pos = move.nextPos
    }
}

extension FieldV2 {
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
        allowedCompType: Int? = nil
    ) -> Bool {
        if let cable = cell(pos: pos).cable,
           cable.compType != allowedCompType {
            return true
        }
        return false
    }
    
    func hasConflictedCable(
        from: Pos,
        to: Pos,
        allowedCompType: Int? = nil
    ) -> Bool {
        let path = Util.getBetweenPos(from: from, to: to)
        for pos in path {
            if hasConflictedCable(at: pos, allowedCompType: allowedCompType) {
                return true
            }
        }
        return false
    }
    
    // Get near computers where connectable
    func getNearComputers(
        aroundComp: Computer,
        loopLimit: Int = 50,
        distF: ((Pos, Pos) -> Int) = Util.distF
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
}
