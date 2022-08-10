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
    
    func getNearestComputer(pos: Pos, dir: Dir, ignoreComp: [Computer] = []) -> Computer? {
        var cPos = pos + dir
        
        while cPos.isValid(boardSize: fieldSize) {
            let cell = cell(pos: cPos)
            if let computer = cell.computer,
               !ignoreComp.contains(computer) {
                return computer
            }
            if cell.isCabled {
                return nil
            }
            cPos += dir
        }
        return nil
    }
    
    func getCluster(ofComputer comp: Computer, ignoreComp: [Computer] = []) -> Set<Int> {
        var cluster = Set<Int>()
        cluster.insert(comp.id)
        
        var q = Queue<Pos>()
        q.push(comp.pos)
        
        while let pos = q.pop() {
            for dir in Dir.all {
                guard let adjacentCompId = getNearestComputer(pos: pos, dir: dir)?.id else {
                    continue
                }
                guard computers[adjacentCompId].type == comp.type,
                      !cluster.contains(adjacentCompId) else {
                    continue
                }
                guard !ignoreComp.contains(computers[adjacentCompId]) else {
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
    
    func calcScoreDiff2(comp: Computer, ignoreComp: [Computer] = []) -> Int {
        var currentClusters = Set<Set<Int>>()
        for dir in Dir.all {
            guard let adjComp = getNearestComputer(pos: comp.pos, dir: dir, ignoreComp: ignoreComp) else {
                continue
            }
            
            currentClusters.insert(getCluster(ofComputer: adjComp, ignoreComp: ignoreComp))
        }
        var removedClusters = Set<Set<Int>>()
        for dir in Dir.all {
            guard let adjComp = getNearestComputer(pos: comp.pos, dir: dir, ignoreComp: ignoreComp + [comp]) else {
                continue
            }
            removedClusters.insert(getCluster(ofComputer: adjComp, ignoreComp: ignoreComp + [comp]))
        }
        
        var scoreDiff: Int = 0
        for cluster in currentClusters {
            scoreDiff -= cluster.count * (cluster.count - 1) / 2
        }
        for cluster in removedClusters {
            scoreDiff += cluster.count * (cluster.count - 1) / 2
        }
        return scoreDiff
    }
    
    func calcScoreDiff(comp: Computer, ignoreComp: [Computer] = []) -> Int {
        var scoreDiff = 0
        var detachedComps = Set<Int>()
        for dir in Dir.all {
            guard let adjComp = getNearestComputer(pos: comp.pos, dir: dir, ignoreComp: ignoreComp) else {
                continue
            }
            if comp.type == adjComp.type {
                detachedComps.formUnion(getCluster(ofComputer: adjComp, ignoreComp: ignoreComp))
            }
        }

        scoreDiff -= detachedComps.count - 1
        
        var mergedComp = Set<Int>()
        
        for (d1, d2) in [(Dir.left, Dir.right), (Dir.up, Dir.down)] {
            guard let comp1 = getNearestComputer(pos: comp.pos, dir: d1, ignoreComp: ignoreComp),
                  let comp2 = getNearestComputer(pos: comp.pos, dir: d2, ignoreComp: ignoreComp) else {
                continue
            }

            if comp1.type != comp2.type {
                continue
            }

            let cluster1 = getCluster(ofComputer: comp1, ignoreComp: ignoreComp)
            let cluster2 = getCluster(ofComputer: comp2, ignoreComp: ignoreComp)

            // Check the pair is not already merged like:
            // xx
            // xox
            //  xx
            if mergedComp == cluster1.union(cluster2) {
                continue
            }
            
            if cluster1 == cluster2 {
                continue
            }

            scoreDiff += cluster1.count * cluster2.count
            mergedComp.formUnion(cluster1)
            mergedComp.formUnion(cluster2)
        }

        return scoreDiff
    }
}

class UnionFind {
    private let n: Int
    private var par: [Int]
    
    init(n: Int) {
        self.n = n
        self.par = [Int](repeating: -1, count: n)
    }

    @discardableResult
    func merge(_ a: Int, _ b: Int) -> Bool {
        var a = root(of: a), b = root(of: b)
        guard a != b else { return false }
        if par[a] > par[b] {
            swap(&a, &b)
        }
        par[a] += par[b]
        par[b] = a
        return true
    }
    
    func same(_ a: Int, _ b: Int) -> Bool {
        root(of: a) == root(of: b)
    }
    
    func root(of a: Int) -> Int {
        if par[a] < 0 {
            return a
        }
        par[a] = root(of: par[a])
        return par[a]
    }
    
    func size(of a: Int) -> Int {
        -par[root(of: a)]
    }
}

