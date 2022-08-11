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
    
    func performMove(move: Move) {
        guard let comp = cell(pos: move.pos).computer else {
            IO.log("Could not find computer at: \(move.pos)", type: .warn)
            return
        }
        moveComputer(comp: comp, to: comp.pos + move.dir)
    }
    
    func performConnect(connect: Connect) {
        connect.comp1.connected.append(connect.comp2)
        connect.comp2.connected.append(connect.comp1)
    }
    
    private func moveComputer(comp: Computer, to: Pos) {
        cells[comp.pos.y][comp.pos.x].computer = nil
        comp.pos = to
        cells[comp.pos.y][comp.pos.x].computer = comp
    }
}

extension Field {
    func getNearestComputer(pos: Pos, dir: Dir, ignoreComp: Computer? = nil) -> Computer? {
        var cPos = pos + dir
        
        while cPos.isValid(boardSize: size) {
            let cell = cell(pos: cPos)
            if let computer = cell.computer,
               computer != ignoreComp {
                return computer
            }
            if cell.isCabled {
                return nil
            }
            cPos += dir
        }
        return nil
    }
    
    func getCluster(ofComputer comp: Computer, ignoreComp: Computer? = nil) -> Set<Int> {
        var cluster = Set<Int>()
        cluster.insert(comp.id)
        
        var q = Queue<Pos>()
        q.push(comp.pos)
        
        while let pos = q.pop() {
            for dir in Dir.all {
                guard let adjacentCompId = getNearestComputer(pos: pos, dir: dir, ignoreComp: ignoreComp)?.id else {
                    continue
                }
                guard computers[adjacentCompId].type == comp.type,
                      !cluster.contains(adjacentCompId) else {
                    continue
                }
                guard ignoreComp != computers[adjacentCompId] else {
                    continue
                }
                
                q.push(computers[adjacentCompId].pos)
                cluster.insert(adjacentCompId)
            }
        }
        
        return cluster
    }
    
    func isInSameCluster(comp1: Computer, comp2: Computer) -> Bool {
        let cluster = getCluster(ofComputer: comp1)
        return cluster.contains(comp2.id)
    }
    
    func calcMoveDiff(comp: Computer, to: Pos) -> Int {
        let removalScore = calcScoreDiff(comp: comp)
        
        let prevPos = comp.pos
        
        // Create temporary field by changing comp.pos
        moveComputer(comp: comp, to: to)
        let movedScore = calcScoreDiff(comp: comp)
        moveComputer(comp: comp, to: prevPos)
        
        print(removalScore, movedScore, prevPos, to)
        return movedScore - removalScore
    }

    // Calc diff of (added - removed)
    func calcScoreDiff(comp: Computer) -> Int {
        var currentClusters = Set<Set<Int>>()
        for dir in Dir.all {
            guard let adjComp = getNearestComputer(pos: comp.pos, dir: dir) else {
                continue
            }
            currentClusters.insert(getCluster(ofComputer: adjComp))
        }
        var removedClusters = Set<Set<Int>>()
        for dir in Dir.all {
            guard let adjComp = getNearestComputer(pos: comp.pos, dir: dir, ignoreComp: comp) else {
                continue
            }
            removedClusters.insert(getCluster(ofComputer: adjComp, ignoreComp: comp))
        }
        
        var scoreDiff: Int = 0
        for cluster in currentClusters {
            scoreDiff += cluster.count * (cluster.count - 1) / 2
        }
        for cluster in removedClusters {
            scoreDiff -= cluster.count * (cluster.count - 1) / 2
        }
        return scoreDiff
    }
    
    func findNearestEmptyCell(pos: Pos, loopLimit: Int = 20, ignorePos: [Pos] = []) -> Pos? {
        var q = Queue<Pos>()
        q.push(pos)
        for _ in 0 ..< loopLimit {
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
        let path = Util.getBetweenPos(from: from, to: to)
        for pos in path {
            if let cable = cell(pos: pos).cable,
               let allowedCable = allowedCable,
               cable != allowedCable {
                return true
            }
        }
        return false
    }
}
