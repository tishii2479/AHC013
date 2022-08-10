class Field {
    struct Cell {
        var computer: Computer?
        var cable: Int?
        
        var isComputer: Bool {
            computer != nil
        }
        var isCabled: Bool {
            cable != nil && cable! > 0
        }
        var isEmpty: Bool {
            !isComputer && !isCabled
        }
    }
    
    let fieldSize: Int
    private(set) var cells: [[Cell]]
    private(set) var computers: [Computer] = []
    
    init(size: Int) {
        fieldSize = size
        cells = [[Cell]](
            repeating: [Cell](
                repeating: Cell(computer: nil, cable: nil),
                count: size
            ),
            count: size
        )
    }
    
    init(size: Int, cells: [[Cell]]) {
        fieldSize = size
        self.cells = cells
    }
    
    func parseField(strs: [String]) {
        for i in 0 ..< fieldSize {
            for j in 0 ..< fieldSize {
                guard let type = strs[i][strs[i].index(strs[i].startIndex, offsetBy: j)].wholeNumberValue else {
                    fatalError("Failed to read field from input")
                }
                
                if type > 0 {
                    let comp = Computer(id: computers.count, type: type, pos: Pos(x: j, y: i))
                    cells[i][j] = Cell(computer: comp, cable: nil)
                    computers.append(comp)
                }
                else {
                    cells[i][j] = Cell(computer: nil, cable: nil)
                }
            }
        }
    }
    
    func cell(pos: Pos) -> Cell {
        cells[pos.y][pos.x]
    }
    
    func getNearestComputer(pos: Pos, dir: Dir, ignoreComp: Computer? = nil) -> Computer? {
        var cPos = pos + dir
        
        while cPos.isValid(boardSize: fieldSize) {
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
    
    func moveComputer(comp: Computer, to: Pos) {
        cells[comp.pos.y][comp.pos.x].computer = nil
        comp.pos = to
        cells[comp.pos.y][comp.pos.x].computer = comp
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
    
}
