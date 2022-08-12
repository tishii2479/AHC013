protocol Solver {
    init(field: Field)
    func solve()
}

class SolverV1 {
    private let field: Field
    private var performedMoves: [Move] = []
    private var connects = Set<Connect>()
    private var temporaryMoves: [Move] = []
    
    private var currentCommands: Int {
        performedMoves.count + connects.count
    }

    init(field: Field) {
        self.field = field
    }

    func solve() -> ([Move], [Connect]) {
        connectOneClusterMst(type: 1, distLimit: 5, costLimit: 5)
        connectOneClusterMst(type: 1, distLimit: 10, costLimit: 10)
        connectOneClusterWithOtherComputer(type: 1)
        connectOneClusterBfs(types: Array(2 ... field.computerTypes), distLimit: 20, costLimit: 10)
        connectOneClusterBfs(types: Array(2 ... field.computerTypes), distLimit: 20, costLimit: 10)
        return (performedMoves, Array(connects))
    }
    
    func connectOneClusterWithOtherComputer(
        type: Int, otherCompLimit: Int = 1, costLimit: Int = 10
    ) {
        for comp1 in field.computerGroup[type] {
            for comp2 in field.computerGroup[type] {
                guard currentCommands + 2 <= field.computerTypes * 100 else {
                    return
                }
                guard comp1.pos.dist(to: comp2.pos) == 2 else {
                    continue
                }
                guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
                    continue
                }
                
                let cluster1 = field.getCluster(ofComputer: comp1)
                let cluster2 = field.getCluster(ofComputer: comp2)
                let currentScore = cluster1.calcScore() + cluster2.calcScore()
                var newCluster = cluster1.merge(cluster2)
                
                if Util.isAligned(comp1.pos, comp2.pos) {
                    // oxo
                    let center = Pos(x: (comp1.pos + comp2.pos).x / 2, y: (comp1.pos + comp2.pos).y / 2)
                    if let comp = field.cell(pos: center).computer {
                        if newCluster.getScore(addType: comp.type) > currentScore {
                            performConnect(connect: Connect(comp1: comp1, comp2: comp))
                            performConnect(connect: Connect(comp1: comp2, comp2: comp))
                        }
                    }
                }
                else {
                    // ox
                    //  o
                    for inter in [
                        Pos(x: comp1.pos.x, y: comp2.pos.y),
                        Pos(x: comp2.pos.x, y: comp1.pos.y)
                    ] {
                        if let comp = field.cell(pos: inter).computer {
                            if newCluster.getScore(addType: comp.type) > currentScore {
                                performConnect(connect: Connect(comp1: comp1, comp2: comp))
                                performConnect(connect: Connect(comp1: comp2, comp2: comp))
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    func connectOneClusterBfs(types: [Int], distLimit: Int = 100, costLimit: Int = 100) {
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }

        let nearComputers = getNearCompPair(types: types, distF: distF)
        var largestClusterSize = 0
        var largestStartComp: Computer? = nil
        
        for _ in 0 ..< 30 {
            guard let type = types.randomElement(),
                  let startComp: Computer = field.computerGroup[type].randomElement() else {
                continue
            }
            let reachableComps = field.getNearComputers(aroundComp: startComp, loopLimit: field.size * field.size, distF: distF)
            if reachableComps.count > largestClusterSize {
                largestClusterSize = reachableComps.count
                largestStartComp = startComp
            }
        }
        
        guard let startComp = largestStartComp else {
            return
        }
        
        IO.log("Selected: ", startComp.type, startComp.pos, largestClusterSize)
        
        var q = Queue<Computer>()
        q.push(startComp)
        while let comp = q.pop() {
            guard let nearComps = nearComputers[comp] else {
                continue
            }
            for (dist, nearComp) in nearComps {
                let connected = connectCompIfPossible(
                    comp1: comp, comp2: nearComp,
                    dist: dist, distLimit: distLimit, costLimit: costLimit
                )
                if connected {
                    q.push(nearComp)
                }
            }
        }
    }
    
    func getNearCompPair(
        types: [Int], distF: (Pos, Pos) -> Int
    ) -> [Computer: [(Int, Computer)]] {
        var ret = [Computer: [(Int, Computer)]]()
        for type in types {
            for comp in field.computerGroup[type] {
                let nearComp = field.getNearComputers(
                    aroundComp: comp,
                    loopLimit: field.size * field.size,
                    distF: distF
                )
                ret[comp] = nearComp
            }
        }
        return ret
    }
    
    func connectOneClusterMst(type: Int, distLimit: Int = 100, costLimit: Int = 100) {
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }
        let compPair = getSortedCompPair(type: type, distLimit: distLimit, distF: distF)
        
        for (dist, (comp1, comp2)) in compPair {
            let _ = connectCompIfPossible(
                comp1: comp1, comp2: comp2,
                dist: dist, distLimit: distLimit, costLimit: costLimit
            )
        }
    }
    
    // Returns true if connected
    private func connectCompIfPossible(
        comp1: Computer, comp2: Computer,
        dist: Int, distLimit: Int, costLimit: Int
    ) -> Bool {
        guard dist <= distLimit else {
            return false
        }
        guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
            return false
        }
        var selectedMoves: [Move]? = nil
        var selectedMoveComp: Computer? = nil

        if let intersections = Util.intersections(comp1.pos, comp2.pos) {
            let currentCluster = field.getCluster(ofComputer: comp1).merge(field.getCluster(ofComputer: comp2))
            for (fromComp, toComp) in [(comp1, comp2), (comp2, comp1)] {
                for inter in intersections {
                    let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: inter) + [inter] +
                        Util.getBetweenPos(from: inter, to: comp2.pos) + [comp2.pos]
                    if let dir = Util.toDir(from: fromComp.pos, to: inter) {
                        // check cable does not get cut
                        if !fromComp.isMovable(dir: dir) {
                            continue
                        }
                        // check extend cables
                        if fromComp.hasConnectedComp(to: dir.rev),
                           !checkConnectable(from: fromComp.pos, to: inter, compType: toComp.type) {
                            continue
                        }
                    }
                    if checkConnectable(from: inter, to: toComp.pos, compType: toComp.type),
                       let moves1 = movesToClear(
                        from: fromComp.pos, to: inter,
                        ignorePos: ignorePos, fixedComp: [fromComp, toComp], addEnd: true
                       ),
                       let moveToInter = moveToInter(from: fromComp.pos, inter: inter),
                       let moves2 = movesToClear(
                        from: inter, to: toComp.pos,
                        ignorePos: ignorePos, fixedComp: [fromComp, toComp]
                       ) {
                        let moves = moves1 + moveToInter + moves2

                        // TODO: consider cable length
                        let didImproved = selectedMoves == nil || moves.count < selectedMoves!.count
                        let newCluster = field.getCluster(ofComputer: comp1).merge(field.getCluster(ofComputer: comp2))
                        let didSustainCluster = currentCluster.comps.isSubset(of: newCluster.comps)
                        if didImproved && didSustainCluster {
                            selectedMoves = moves
                            selectedMoveComp = fromComp
                        }
                    }
                    reverseTemporaryMoves()
                }
            }
        }
        else {
            // is already aligned
            let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: comp2.pos) + [comp2.pos]
            if checkConnectable(from: comp1.pos, to: comp2.pos, compType: comp1.type),
               let moves = movesToClear(from: comp1.pos, to: comp2.pos,
                                        ignorePos: ignorePos, fixedComp: [comp1, comp2]) {
                selectedMoves = moves
            }
            reverseTemporaryMoves()
        }
        
        return performCommandIfPossible(
            moves: selectedMoves, comp1: comp1, comp2: comp2,
            costLimit: costLimit, selectedMoveComp: selectedMoveComp
        )
    }
    
    private func performCommandIfPossible(
        moves: [Move]?, comp1: Computer, comp2: Computer,
        costLimit: Int, selectedMoveComp: Computer? = nil
    ) -> Bool {
        if let moves = moves {
            let cost = moves.count + 1
            // Check command limit
            let satisfyCommandLimit = currentCommands + cost <= field.computerTypes * 100
            let satisfyCostLimit = cost < costLimit
           if satisfyCommandLimit && satisfyCostLimit {
                performMoves(moves: moves)
                performConnect(connect: Connect(comp1: comp1, comp2: comp2), movedComp: selectedMoveComp)
               return true
           }
        }
        return false
    }
    
    private func getSortedCompPair(type: Int, distLimit: Int, distF: (Pos, Pos) -> Int) -> [(Int, (Computer, Computer))] {
        var compPair = [(Int, (Computer, Computer))]()
        for comp1 in field.computerGroup[type] {
            for comp2 in field.computerGroup[type] {
                guard comp1 != comp2 else { continue }
                
                let dist = distF(comp1.pos, comp2.pos)
                if dist < distLimit {
                    compPair.append((dist, (comp1, comp2)))
                }
            }
        }
        
        return compPair.sorted(by: { (a, b) in
            return a.0 < b.0
        })
    }
    
    private func checkConnectable(from: Pos, to: Pos, compType: Int) -> Bool {
        guard let dir = Util.toDir(from: from, to: to) else {
            return false
        }
        let direction = Util.fromDir(dir: dir)
        let val = !field.hasConflictedCable(
            from: from,
            to: to,
            allowedCompType: compType,
            allowedDirection: direction
        )
        return val
    }
    
    func moveToInter(from: Pos, inter: Pos) -> [Move]? {
        guard let interMoves = Util.getMoves(from: from, to: inter) else {
            return nil
        }
        performTemporaryMoves(moves: interMoves)
        return interMoves
    }
    
    func movesToClear(from: Pos, to: Pos, ignorePos: [Pos], fixedComp: [Computer], addEnd: Bool = false) -> [Move]? {
        let path = Util.getBetweenPos(from: from, to: to, addEnd: addEnd)
        var clearMoves = [Move]()
        for pos in path {
            guard field.cell(pos: pos).isComputer else { continue }
            
            guard let emptyPos = field.findNearestEmptyCell(at: pos, ignorePos: ignorePos) else {
//                IO.log("Could not find empty cell")
                return nil
            }
            
            guard let movesToEmpty = movesToEmptyCell(from: pos, to: emptyPos, fixedComp: fixedComp) else {
                return nil
            }

            performTemporaryMoves(moves: movesToEmpty)
            clearMoves.append(contentsOf: movesToEmpty)
        }
        return clearMoves
    }
    
    func movesToEmptyCell(from: Pos, to: Pos, fixedComp: [Computer], trialLimit: Int = 20) -> [Move]? {
        let dy = to.y - from.y
        let dx = to.x - from.x
        
        var dirs: [Dir] = []
        if dy < 0 {
            dirs.append(contentsOf: [Dir](repeating: .up, count: abs(dy)))
        }
        else if dy > 0 {
            dirs.append(contentsOf: [Dir](repeating: .down, count: abs(dy)))
        }
        
        if dx < 0 {
            dirs.append(contentsOf: [Dir](repeating: .left, count: abs(dx)))
        }
        else if dx > 0 {
            dirs.append(contentsOf: [Dir](repeating: .right, count: abs(dx)))
        }
        
        // TODO: select optimal order
        
        for _ in 0 ..< trialLimit {
            dirs.shuffle()

            var cPos: Pos = from
            var disallowedMove = false
            var ret = [Move]()
            
            for dir in dirs {
                guard let comp = field.cell(pos: cPos).computer,
                      // Cable won't extend automatically,
                      // so another computer may come on the extended cable
                      // instead of `comp.isMovable(dir: dir)`
                      !comp.isConnected,
                      !fixedComp.contains(comp),
                      !field.hasConflictedCable(at: cPos) else {
                    disallowedMove = true
                    break
                }
                ret.append(Move(pos: cPos, dir: dir))
                cPos += dir
            }
            
            if !disallowedMove {
                return ret.reversed()
            }
        }
            
        return nil
    }
    
    private func performTemporaryMoves(moves: [Move]) {
        for move in moves {
            temporaryMoves.append(move)
            field.performMove(move: move)
        }
    }

    private func reverseTemporaryMoves() {
        field.reverseMoves(moves: temporaryMoves)
        temporaryMoves.removeAll()
    }
    
    private func performMoves(moves: [Move]) {
        for move in moves {
            performedMoves.append(move)
            field.performMove(move: move)
        }
    }
    
    private func performConnect(connect: Connect, movedComp: Computer? = nil) {
        if let movedComp = movedComp,
           let cable = field.cell(pos: movedComp.pos).cable,
           cable.compType == movedComp.type {
            connects.remove(Connect(comp1: cable.comp1, comp2: cable.comp2))

            connects.insert(Connect(comp1: cable.comp1, comp2: movedComp))
            connects.insert(Connect(comp1: cable.comp2, comp2: movedComp))
        }
        else {
            connects.insert(connect)
        }
        field.performConnect(connect: connect, movedComp: movedComp)
    }
}
