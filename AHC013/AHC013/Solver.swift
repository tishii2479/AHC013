protocol Solver {
    init(field: Field)
}

final class SolverV1: Solver {
    let field: Field
    private(set) var performedMoves: [Move] = []
    private(set) var connects = Set<Connect>()
    private var mainType: Int = 0
    
    private var nearComputers: [Computer: [(Int, Computer)]] = [:]
    
    private var currentCommands: Int {
        performedMoves.count + connects.count
    }

    init(field: Field) {
        self.field = field
        nearComputers = getNearCompPair(
            types: Array(1 ... field.computerTypes), distF: Util.distF,
            distLimit: 20
        )
    }
    
    init(field: Field, performedMoves: [Move], connects: Set<Connect>) {
        self.field = field
        self.performedMoves = performedMoves
        self.connects = connects
    }

    func constructFirstCluster(type: Int, param: Parameter) -> (Int, Int) {
        mainType = type
        connectOneClusterMst(type: type, distLimit: param.distLimit, costLimit: param.costLimit)
        connectOneClusterMst(type: type, distLimit: param.distLimit * 2, costLimit: param.costLimit * 2)
        connectOneClusterWithOtherComputer(type: type)
        return (field.calcScore(), currentCommands)
    }
    
    func constructSecondCluster(param: Parameter) -> (Int, Int) {
        connectOneClusterBfs(
            types: Array(1 ... field.computerTypes).filter{ $0 != mainType },
            distLimit: 20,
            costLimit: param.costLimit
        )
        return (field.calcScore(), currentCommands)
    }
    
    func constructOtherClusters(param: Parameter) -> (Int, Int) {
        var costLimit = param.costLimit
        while Time.isInTime() {
            connectOneClusterBfs(
                types: Array(1 ... field.computerTypes).filter{ $0 != mainType },
                distLimit: 10,
                costLimit: costLimit
            )
            costLimit += 1
        }
        return (field.calcScore(), currentCommands)
    }
}

extension SolverV1 {
    func connectOneClusterMst(type: Int, distLimit: Int = 100, costLimit: Int = 100) {
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            Util.distF(a, b) + Int.random(in: -1 ... 1)
        }
        let compPair = getSortedCompPair(type: type, distLimit: distLimit, distF: distF)
        for (dist, (comp1, comp2)) in compPair {
            guard Time.isInTime() else { return }
            let _ = connectCompIfPossible(
                comp1: comp1, comp2: comp2,
                dist: dist, distLimit: distLimit, costLimit: costLimit
            )
        }
    }
    
    func connectOneClusterBfs(types: [Int], distLimit: Int = 100, costLimit: Int = 100, trialLimit: Int = 30) {
        guard Time.isInTime() else { return }
        var largestClusterSize = 0
        var largestStartComp: Computer? = nil
        
//        IO.log("connectOneClusterBfs:searchStartComp:start", Time.elapsedTime())
        for _ in 0 ..< trialLimit {
            guard Time.isInTime() else { return }
            guard let type = types.randomElement(),
                  let startComp: Computer = field.computerGroup[type].randomElement(),
                  !startComp.isConnected else {
                continue
            }
            let reachableComps = field.getNearComputers(aroundComp: startComp, loopLimit: field.size * field.size, distF: Util.distF)
            if reachableComps.count > largestClusterSize {
                largestClusterSize = reachableComps.count
                largestStartComp = startComp
            }
        }
//        IO.log("connectOneClusterBfs:searchStartComp:end", Time.elapsedTime())
        
        guard let startComp = largestStartComp else {
            return
        }
        
//        IO.log("Selected:", startComp.type, startComp.pos, largestClusterSize)
        
        var q = Queue<Computer>()
        q.push(startComp)
        while let comp = q.pop() {
            guard Time.isInTime() else { return }
            guard let nearComps = nearComputers[comp] else {
                continue
            }
            for (_, nearComp) in nearComps {
                guard Time.isInTime() else { return }
                let dist = Util.distF(comp.pos, nearComp.pos)
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
    
    func connectOneClusterWithOtherComputer(
        type: Int, otherCompLimit: Int = 1,
        distLimit: Int = 4, costLimit: Int = 10,
        trialLimit: Int = 10
    ) {
        let compPair = getSortedCompPair(type: type, distLimit: distLimit, distF: Util.distF)
        for (dist, (comp1, comp2)) in compPair {
            guard Time.isInTime() else { return }
            guard currentCommands + dist <= field.computerTypes * 100 else {
                return
            }
            guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
                continue
            }
            
            let cluster1 = field.getCluster(ofComputer: comp1)
            let cluster2 = field.getCluster(ofComputer: comp2)
            let currentScore = cluster1.calcScore() + cluster2.calcScore()
            var newCluster = cluster1.merged(cluster2)
            var bestConnects: [Connect]? = nil
            var bestPrepareMoves = [Move]()
            var bestImprovedScore = 0
            
            for pos1 in field.movable(comp: comp1, moveLimit: 3) {
                for pos2 in field.movable(comp: comp2, moveLimit: 3) {
                    guard Time.isInTime() else { return }
                    guard pos1 != pos2 else { continue }
                    
                    var dirs = Util.dirsForPath(from: pos1, to: pos2)
                    
                    for _ in 0 ..< trialLimit {
                        dirs.shuffle()
                        var cPos = pos1
                        var cComp = comp1
                        var ok = true
                        var tempConnects = [Connect]()
                        var connectedComps = [Computer]()
                        
                        for i in 0 ..< dirs.count {
                            let nextPos = cPos + dirs[i]
                            //
                            let isCorner = i + 1 < dirs.count && dirs[i] != dirs[i + 1]
                            guard nextPos != comp1.pos else {
                                ok = false
                                break
                            }
                            if let comp = field.cell(pos: nextPos).computer {
                                connectedComps.append(comp)
                                tempConnects.append(Connect(comp1: cComp, comp2: comp))
                                cComp = comp
                            }
                            else if field.cell(pos: nextPos).isCabled || isCorner {
                                ok = false
                                break
                            }
                            cPos += dirs[i]
                        }
                        guard ok else { continue }
                        
                        let newComputerTypes = connectedComps.filter{ $0.type != comp1.type }.map{ $0.type }
                        let improvedScore = newCluster.getScore(addTypes: newComputerTypes) - currentScore
                        if let moves1 = Util.getMoves(from: comp1.pos, to: pos1),
                           let moves2 = Util.getMoves(from: comp2.pos, to: pos2),
                           improvedScore > bestImprovedScore,
                           bestConnects == nil || tempConnects.count < bestConnects!.count,
                           currentCommands + moves1.count + moves2.count + tempConnects.count <= field.computerTypes * 100 {
                            bestImprovedScore = improvedScore
                            bestConnects = tempConnects
                            bestPrepareMoves = moves1 + moves2
                        }
                    }
                }
            }
            
            if bestImprovedScore > 0,
               let bestConnects = bestConnects {
                performMoves(moves: bestPrepareMoves)
                for connect in bestConnects {
                    performConnect(connect: connect)
                }
            }
        }
    }
}

extension SolverV1 {
    private func getMovesToConnectComp(
        comp1: Computer, comp2: Computer
    ) -> ([Move]?, Computer?) {
        var selectedMoves: [Move]? = nil
        var selectedMovedComp: Computer? = nil
        
        let currentScore = field.getCluster(ofComputer: comp1).calcScore()
            + field.getCluster(ofComputer: comp2).calcScore()

        let intersections = Util.intersections(comp1.pos, comp2.pos)
        for (fromComp, toComp) in [(comp1, comp2), (comp2, comp1)] {
            for inter in intersections {
                var temporaryMoves: [Move] = []
                defer { reverseTemporaryMoves(moves: temporaryMoves) }
                let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: inter) + [inter] +
                    Util.getBetweenPos(from: inter, to: comp2.pos) + [comp2.pos]
                if let dir = Util.toDir(from: fromComp.pos, to: inter) {
                    // check cable does not get cut
                    if !fromComp.isMovable(dir: dir) {
                        continue
                    }
                    // check extend cables
                    if fromComp.connectedComp(to: dir.rev) != nil,
                       !checkConnectable(from: fromComp.pos, to: inter, compType: toComp.type) {
                        continue
                    }
                }
                guard checkConnectable(from: inter, to: toComp.pos, compType: toComp.type) else {
                    continue
                }

                // TODO: refactor
                let (isCompleted1, moves1) = movesToClear(
                    from: fromComp.pos, to: inter,
                    ignorePos: ignorePos, fixedComp: [fromComp, toComp], addEnd: true
                )
                temporaryMoves.append(contentsOf: moves1)
                guard isCompleted1 else { continue }
                let (isCompleted2, moves2) = moveToInter(from: fromComp.pos, inter: inter)
                temporaryMoves.append(contentsOf: moves2)
                guard isCompleted2 else { continue }
                let (isCompleted3, moves3) = movesToClear(
                    from: inter, to: toComp.pos,
                    ignorePos: ignorePos, fixedComp: [fromComp, toComp]
                )
                temporaryMoves.append(contentsOf: moves3)
                guard isCompleted3 else { continue }

                let moves = moves1 + moves2 + moves3
                let didImprovedMoves = selectedMoves == nil || moves.count < selectedMoves!.count
                let newCluster = field.getCluster(ofComputer: comp1).merged(field.getCluster(ofComputer: comp2))
                let didImproveScore = newCluster.calcScore() > currentScore
                if didImprovedMoves && didImproveScore {
                    selectedMoves = moves
                    selectedMovedComp = fromComp
                }
            }
        }
        return (selectedMoves, selectedMovedComp)
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
        
        guard let (moves, movedComp) =
                getMovesToConnectComp(comp1: comp1, comp2: comp2) as? ([Move], Computer?) else {
            return false
        }
        
        return performCommandIfPossible(
            moves: moves, connects: [Connect(comp1: comp1, comp2: comp2)],
            costLimit: costLimit, movedComps: [movedComp]
        )
    }
    
    private func performCommandIfPossible(
        moves: [Move], connects: [Connect],
        costLimit: Int, movedComps: [Computer?] = []
    ) -> Bool {
        let cost = moves.count + connects.count
        // Check command limit
        let satisfyCommandLimit = currentCommands + cost <= field.computerTypes * 100
        let satisfyCostLimit = cost < costLimit
        if satisfyCommandLimit && satisfyCostLimit {
            performMoves(moves: moves)
            for (connect, movedComp) in zip(connects, movedComps) {
                performConnect(connect: connect, movedComp: movedComp)
            }
            return true
        }
        return false
    }
    
    private func getSortedCompPair(type: Int, distLimit: Int, distF: (Pos, Pos) -> Int) -> [(Int, (Computer, Computer))] {
        var compPair = [(Int, (Computer, Computer))]()
        for comp1 in field.computerGroup[type] {
            for comp2 in field.computerGroup[type] {
                guard comp1 != comp2 else { continue }
                
                let dist = distF(comp1.pos, comp2.pos)
                if dist <= distLimit {
                    compPair.append((dist, (comp1, comp2)))
                }
            }
        }
        return compPair.sorted(by: { (a, b) in
            return a.0 < b.0
        })
    }
    
    // TODO: change process
    // ISSUE: slow
    private func getNearCompPair(
        types: [Int], distF: (Pos, Pos) -> Int,
        distLimit: Int, maxSize: Int = 10
    ) -> [Computer: [(Int, Computer)]] {
        IO.log("getNearCompPair:start", Time.elapsedTime())
        var ret = [Computer: [(Int, Computer)]]()
        for type in types {
            for comp in field.computerGroup[type] {
                let nearComp = field.getNearComputers(
                    aroundComp: comp,
                    loopLimit: distLimit * distLimit,
                    distLimit: distLimit,
                    distF: distF,
                    maxSize: maxSize
                )
                ret[comp] = nearComp
            }
        }
        IO.log("getNearCompPair:end", Time.elapsedTime())
        return ret
    }
    
    // TODO: change process
    // ISSUE: slow
    // Not used
    private func getNearCompPair2(
        types: [Int], distF: (Pos, Pos) -> Int,
        distLimit: Int
    ) -> [Computer: [(Int, Computer)]] {
        IO.log("getNearCompPair:start", Time.elapsedTime())
        var ret = [Computer: [(Int, Computer)]]()
        for type in types {
            for (dist, (comp1, comp2)) in getSortedCompPair(type: type, distLimit: distLimit, distF: distF) {
                if ret[comp1] == nil {
                    ret[comp1] = []
                }
                if ret[comp2] == nil {
                    ret[comp2] = []
                }
                if dist <= distLimit {
                    ret[comp1]?.append((dist, comp2))
                    ret[comp2]?.append((dist, comp1))
                }
            }
        }
        IO.log("getNearCompPair:end", Time.elapsedTime())
        return ret
    }
    
    private func checkConnectable(from: Pos, to: Pos, compType: Int) -> Bool {
        guard let dir = Util.toDir(from: from, to: to) else {
            return false
        }
        let direction = Util.fromDir(dir: dir)
        return !field.hasConflictedCable(
            from: from,
            to: to,
            allowedCompType: compType,
            allowedDirection: direction
        )
    }
    
    func moveToInter(from: Pos, inter: Pos) -> (Bool, [Move]) {
        guard let interMoves = Util.getMoves(from: from, to: inter) else {
            return (false, [])
        }
        performTemporaryMoves(moves: interMoves)
        return (true, interMoves)
    }
    
    func movesToClear(from: Pos, to: Pos, ignorePos: [Pos], fixedComp: [Computer], addEnd: Bool = false) -> (Bool, [Move]) {
        let path = Util.getBetweenPos(from: from, to: to, addEnd: addEnd)
        var clearMoves = [Move]()
        for pos in path {
            guard field.cell(pos: pos).isComputer else { continue }
            guard let emptyPos = field.findNearestEmptyCell(at: pos, ignorePos: ignorePos) else {
//                IO.log("Could not find empty cell")
                return (false, clearMoves)
            }
            guard let movesToEmpty = movesToEmptyCell(from: pos, to: emptyPos, fixedComp: fixedComp) else {
                return (false, clearMoves)
            }
            performTemporaryMoves(moves: movesToEmpty)
            clearMoves.append(contentsOf: movesToEmpty)
        }
        return (true, clearMoves)
    }
    
    func movesToEmptyCell(from: Pos, to: Pos, fixedComp: [Computer], trialLimit: Int = 20) -> [Move]? {
        var dirs = Util.dirsForPath(from: from, to: to)

        var bestRet: [Move]? = nil
        var bestScore = -123456
        
        for _ in 0 ..< min(dirs.count * 2, trialLimit) {
            dirs.shuffle()

            var cPos: Pos = from
            var disallowedMove = false
            var ret = [Move]()
            var score = 0
            
            for dir in dirs {
                guard let comp = field.cell(pos: cPos).computer,
                      let nearComps = nearComputers[comp],
                      // Cable won't extend automatically,
                      // so another computer may come on the extended cable
                      // instead of `comp.isMovable(dir: dir)`
                      !comp.isConnected,
                      !fixedComp.contains(comp),
                      !field.hasConflictedCable(at: cPos) else {
                    disallowedMove = true
                    break
                }
                for (_, nearComp) in nearComps.prefix(5) {
                    let scoreDelta = Util.isAligned(nearComp.pos, comp.pos + dir) ? 1 : 0
                        - (Util.isAligned(nearComp.pos, comp.pos) ? 1 : 0)
                    score += scoreDelta
                }
                ret.append(Move(pos: cPos, dir: dir))
                cPos += dir
            }
            
            if !disallowedMove && score > bestScore {
                bestScore = score
                bestRet = ret
            }
        }

        return bestRet?.reversed()
    }
    
    private func performTemporaryMoves(moves: [Move]) {
        for move in moves {
            field.performMove(move: move, isTemporary: true)
        }
    }

    private func reverseTemporaryMoves(moves: [Move]) {
        field.reverseMoves(moves: moves)
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
    
    private func resetConnect(connect: Connect) {
        connects.remove(connect)
        field.resetConnect(connect: connect)
    }
    
    func copy() -> SolverV1 {
        SolverV1(
            field: field.copy(),
            performedMoves: performedMoves,
            connects: connects
        )
    }
}
