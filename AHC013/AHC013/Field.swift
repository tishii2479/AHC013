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
    
    func getAdjacentComputer(pos: Pos, dir: Dir) -> Computer? {
        var cPos = pos + dir
        
        while cPos.isValid(boardSize: fieldSize) {
            let cell = cell(pos: cPos)
            if let computer = cell.computer {
                return computer
            }
            if cell.isCabled {
                return nil
            }
            cPos += dir
        }
        return nil
    }

    func getCluster(ofComputerIdx compIdx: Int) -> Set<Int> {
        var cluster = Set<Int>()
        cluster.insert(compIdx)
        
        var q = Queue<Pos>()
        q.push(computers[compIdx].pos)
        
        while let pos = q.pop() {
            for dir in Dir.all {
                guard let adjacentCompIdx = getAdjacentComputer(pos: pos, dir: dir)?.id else {
                    continue
                }
                guard computers[adjacentCompIdx].type == computers[compIdx].type,
                      !cluster.contains(adjacentCompIdx) else {
                    continue
                }
                
                q.push(computers[adjacentCompIdx].pos)
                cluster.insert(adjacentCompIdx)
            }
        }
        
        return cluster
    }
    
    func isInSameCluster(compIdx1: Int, compIdx2: Int) -> Bool {
        let cluster = getCluster(ofComputerIdx: compIdx1)
        return cluster.contains(compIdx2)
    }
}
