protocol Solver {
    init(field: Field)
}

final class SolverV1: Solver {
    let field: Field
    private(set) var performedMoves: [Move] = []
    private(set) var connects = Set<Connect>()
    private var mainType: Int = 0
    
    private var nearComputers: [Computer: [(Int, Computer)]] = [:]
    private var reconnectablePairs: [(Int, Computer, Computer)] = []
    
    var currentCommands: Int {
        performedMoves.count + connects.count
    }

    init(field: Field) {
        self.field = field
        nearComputers = getNearCompPair(
            types: Array(1 ... field.computerTypes), distF: Util.distF,
            distLimit: field.size / 2
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
        
        reconnectablePairs = prepareReconnectablePairs()

        return (field.calcScore(), currentCommands)
    }
    
    func constructSecondCluster(param: Parameter) -> (Int, Int) {
        if let cluster = connectOneClusterBfs(
            types: Array(1 ... field.computerTypes).filter{ $0 != mainType },
            distLimit: field.size / 2,
            costLimit: param.costLimit,
            extend: true
        ) {
            let _ = connectOneClusterBfs(
                types: Array(1 ... field.computerTypes).filter{ $0 != mainType },
                distLimit: field.size / 2,
                costLimit: param.costLimit * 2,
                extend: true,
                startComps: Array(cluster.comps)
            )
        }
        return (field.calcScore(), currentCommands)
    }
    
    func constructOtherClusters(param: Parameter) -> (Int, Int) {
        var costLimit = param.costLimit
        while Time.isInTime() {
            let _ = connectOneClusterBfs(
                types: Array(1 ... field.computerTypes).filter{ $0 != mainType },
                distLimit: field.size / 3,
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
    
    func connectOneClusterBfs(
        types: [Int], distLimit: Int = 100,
        costLimit: Int = 100, trialLimit: Int = 30,
        extend: Bool = false,
        startComps: [Computer]? = nil
    ) -> Cluster? {
//        IO.log("Selected:", startComp.type, startComp.pos, largestClusterSize)
        var q = Queue<Computer>()
        var cluster = Cluster(comps: [], types: field.computerTypes)
        
        if let startComps = startComps {
            for comp in startComps {
                q.push(comp)
                cluster.add(comp: comp)
            }
        }
        else if let startComp = findStartCompForBfs(trialLimit: trialLimit, types: types) {
            q.push(startComp)
            cluster.add(comp: startComp)
        }

        while let comp = q.pop() {
            guard Time.isInTime() else { return cluster }
            guard let nearComps = nearComputers[comp] else {
                continue
            }
            for (_, nearComp) in nearComps {
                guard Time.isInTime() else { return cluster }
                let dist = Util.distF(comp.pos, nearComp.pos)
                var connected = connectCompIfPossible(
                    comp1: comp, comp2: nearComp,
                    dist: dist, distLimit: distLimit, costLimit: costLimit
                )
                if !connected && extend {
                    connected = extendClusterByReconnecting(
                        compInCluster: comp, compToConnect: nearComp,
                        costLimit: costLimit
                    )
                }
                // extend bfs
                if connected {
                    q.push(nearComp)
                    cluster.add(comp: nearComp)
                }
            }
        }
        
        return cluster
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
    
    // let comp1, comp2
    // find cable between comp1, inter
    // compA, compB = cable.comps
    // disconnect compA, compB
    // move comp2 to temporary position
    // newCompA, newCompB = reconnectComp
    // getMovesToConnectComp newCompA, newCompB
    //      ignorePos, between newCompA and newCompB, between compA, compB
    //      fixedComp, newCompA, newCompB, compA, compB
    // getMovesToConnectComp comp1, comp2
    //      ignorePos, between newCompA and newCompB, between compA, compB
    //      fixedComp, newCompA, newCompB, compA, compB
    // reset temporary move comp2
    // add moves comp2 to temporary position to movesToConnect
    // if possible perform moves, connect
    func extendClusterByReconnecting(
        compInCluster: Computer, compToConnect: Computer,
        costLimit: Int
    ) -> Bool {
        guard !field.isInSameCluster(comp1: compInCluster, comp2: compToConnect) else {
            return false
        }
        let intersection = Util.intersections(compInCluster.pos, compToConnect.pos)
        for inter in intersection {
            guard let cable = findCableToReconnect(
                from: compInCluster.pos, to: inter,
                compType: compInCluster.type, fixedComp: [compInCluster, compToConnect]
            ) else {
                continue
            }
            let testCutConnect = Connect(comp1: cable.comp1, comp2: cable.comp2)
            var temporaryMoves = [Move]()
            var isReconnected: Bool = false
            resetConnect(connect: testCutConnect)
            defer {
                reverseTemporaryMoves(moves: temporaryMoves)
                if !isReconnected {
                    performConnect(connect: testCutConnect)
                }
            }

            if let dir = Util.toDir(from: compToConnect.pos, to: inter) {
                // check cable does not get cut
                if !compToConnect.isMovable(dir: dir) {
                    continue
                }
                // check extend cables
                if compToConnect.connectedComp(to: dir.rev) != nil,
                   !checkConnectable(from: compToConnect.pos, to: inter, compType: compToConnect.type) {
                    continue
                }
            }
            guard checkConnectable(
                from: inter, to: compInCluster.pos, compType: compInCluster.type) else {
                continue
            }
            
            let ignorePosToClear = [compInCluster.pos, inter, compToConnect.pos, cable.comp1.pos, cable.comp2.pos]
                + Util.getBetweenPos(from: compInCluster.pos, to: inter)
                + Util.getBetweenPos(from: inter, to: compToConnect.pos)
            let (isCompleted1, moves1) = movesToClear(
                from: compToConnect.pos, to: inter, ignorePos: ignorePosToClear,
                fixedComp: [compInCluster, compToConnect, cable.comp1, cable.comp2],
                addEnd: true)
            temporaryMoves.append(contentsOf: moves1)
            guard isCompleted1 else { continue }

            let (isCompleted2, moves2) = moveToPos(from: compToConnect.pos, pos: inter)
            temporaryMoves.append(contentsOf: moves2)
            guard isCompleted2 else { continue }

            guard let (reconnectComp1, reconnectComp2) = findReconnection(
                comp1: cable.comp1, comp2: cable.comp2,
                ignorePos: Util.getBetweenPos(from: inter, to: compInCluster.pos),
                fixedComp: [compInCluster, compToConnect]
            ) else {
                continue
            }
            
            let ignorePos = Util.getBetweenPos(from: compInCluster.pos, to: inter)
                            + Util.getBetweenPos(from: reconnectComp1.pos, to: reconnectComp2.pos)
                            + [compInCluster.pos, compToConnect.pos,
                               reconnectComp1.pos,  reconnectComp2.pos]
            let fixedComp = [compInCluster, compToConnect, reconnectComp1, reconnectComp2]
            
            guard let (movesToReconnect, movedCompToReconnect) = getMovesToConnectComp(
                comp1: reconnectComp1, comp2: reconnectComp2,
                additionalIgnorePos: ignorePos, additionalFixedComp: fixedComp,
                checkImproveScore: false) as? ([Move], Computer?) else {
                continue
            }
            temporaryMoves.append(contentsOf: movesToReconnect)
            performTemporaryMoves(moves: movesToReconnect)
            
            guard let (movesToExtend, movedCompToExtend) = getMovesToConnectComp(
                    comp1: compInCluster, comp2: compToConnect,
                    additionalIgnorePos: ignorePos, additionalFixedComp: fixedComp,
                    checkImproveScore: false) as? ([Move], Computer?) else {
                continue
            }
            temporaryMoves.append(contentsOf: movesToExtend)
            performTemporaryMoves(moves: movesToExtend)
            
//            IO.log("cable: \(cable.comp1.pos), \(cable.comp2.pos), \(cable.compType)")
//            IO.log("found reconnection: \(reconnectComp1.pos), \(reconnectComp2.pos)")

            reverseTemporaryMoves(moves: temporaryMoves)
            temporaryMoves.removeAll()
            
            let moves = moves1 + moves2 + movesToReconnect + movesToExtend
            let connects = [
                Connect(comp1: reconnectComp1, comp2: reconnectComp2),
                Connect(comp1: compInCluster, comp2: compToConnect)
            ]
            let movedComps = [movedCompToReconnect, movedCompToExtend]

            if performCommandIfPossible(
                moves: moves, connects: connects, costLimit: costLimit, movedComps: movedComps
            ) {
//                IO.log("extended: \(compInCluster.pos), \(compToConnect.pos)")
//                IO.log("cable: \(cable.comp1.pos), \(cable.comp2.pos), \(cable.compType)")
//                IO.log("found reconnection: \(reconnectComp1.pos), \(reconnectComp2.pos)")
                isReconnected = true
                return true
            }
        }
        return false
    }
    
    private func findStartCompForBfs(
        trialLimit: Int, types: [Int]
    ) -> Computer? {
        guard Time.isInTime() else { return nil }
        var largestClusterSize = 0
        var largestStartComp: Computer? = nil
        
//        IO.log("connectOneClusterBfs:searchStartComp:start", Time.elapsedTime())
        for _ in 0 ..< trialLimit {
            guard Time.isInTime() else { return nil }
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
        
        return largestStartComp
    }

    private func findCableToReconnect(
        from: Pos, to: Pos, compType: Int,
        fixedComp: [Computer]
    ) -> Cable? {
        // check cables between from and pos
        var existingCable: Cable? = nil
        for pos in [from, to] + Util.getBetweenPos(from: from, to: to) {
            if let comp = field.cell(pos: pos).computer,
               fixedComp.contains(comp) && comp.type != compType  {
                return nil
            }
            if let cable = field.cell(pos: pos).cable,
               cable.compType != compType {
                // only reconnect one cable
                // interrupt if there are two cables
                if existingCable != nil {
                    return nil
                }
                existingCable = cable
            }
        }
        return existingCable
    }

    private func findReconnection(
        comp1: Computer, comp2: Computer,
        ignorePos: [Pos], fixedComp: [Computer]
    ) -> (Computer, Computer)? {
        let cluster1 = field.getPreciseCluster(ofComputer: comp1)
        let cluster2 = field.getPreciseCluster(ofComputer: comp2)
        
        for (_, newComp1, newComp2) in reconnectablePairs {
            guard !connects.contains(Connect(comp1: newComp1, comp2: newComp2)) else {
                continue
            }
            guard !(comp1 == newComp1 && comp2 == newComp2) &&
                    !(comp1 == newComp2 && comp2 == newComp1)else {
                continue
            }
            guard (cluster1.comps.contains(newComp1) && cluster2.comps.contains(newComp2))
                    || (cluster1.comps.contains(newComp2) && cluster2.comps.contains(newComp1)) else {
                continue
            }
            var doesIntersect = false
            // check if the new cable is not on ignorePos
            for pos in Util.getBetweenPos(from: newComp1.pos, to: newComp2.pos) {
                if ignorePos.contains(pos) {
                    doesIntersect = true
                    break
                }
            }
            guard !doesIntersect else {
                continue
            }
            if let _ = getMovesToConnectComp(
                comp1: newComp1, comp2: newComp2, additionalIgnorePos: ignorePos,
                additionalFixedComp: fixedComp, checkImproveScore: false) as? ([Move], Computer?) {
                return (newComp1, newComp2)
            }
        }
        return nil
    }
}

extension SolverV1 {
    private func getMovesToConnectComp(
        comp1: Computer, comp2: Computer,
        additionalIgnorePos: [Pos] = [],
        additionalFixedComp: [Computer] = [],
        checkImproveScore: Bool = true
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
                let ignorePos = [comp1.pos, inter, comp2.pos]
                    + Util.getBetweenPos(from: comp1.pos, to: inter)
                    + Util.getBetweenPos(from: inter, to: comp2.pos)
                    + additionalIgnorePos
                let fixedComp = [fromComp, toComp] + additionalFixedComp
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
                    ignorePos: ignorePos, fixedComp: fixedComp, addEnd: true
                )
                temporaryMoves.append(contentsOf: moves1)
                guard isCompleted1 else { continue }
                let (isCompleted2, moves2) = moveToPos(from: fromComp.pos, pos: inter)
                temporaryMoves.append(contentsOf: moves2)
                guard isCompleted2 else { continue }
                let (isCompleted3, moves3) = movesToClear(
                    from: inter, to: toComp.pos,
                    ignorePos: ignorePos, fixedComp: fixedComp
                )
                temporaryMoves.append(contentsOf: moves3)
                guard isCompleted3 else { continue }

                let moves = moves1 + moves2 + moves3
                let didImprovedMoves = selectedMoves == nil || moves.count < selectedMoves!.count
                let newCluster = field.getCluster(ofComputer: comp1).merged(field.getCluster(ofComputer: comp2))
                let didImproveScore = !checkImproveScore || newCluster.calcScore() > currentScore
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
                guard Time.isInTime() else { break }
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
    
    private func prepareReconnectablePairs() -> [(Int, Computer, Computer)] {
        IO.log("start:", Time.elapsedTime())
        var pairs: [(Int, Computer, Computer)] = []
        for comp1 in field.computerGroup[mainType] {
            for comp2 in field.computerGroup[mainType] {
                guard Time.isInTime() else { break }
                let connect = Connect(comp1: comp1, comp2: comp2)
                guard !connects.contains(connect) else { continue }
                // TODO: temporary, remove
                guard Util.isAligned(comp1.pos, comp2.pos) else {
                    continue
                }
                if let (moves, _) = getMovesToConnectComp(
                    comp1: comp1, comp2: comp2, checkImproveScore: false) as? ([Move], Computer?) {
                    pairs.append((moves.count, comp1, comp2))
                }
            }
        }
        IO.log("end:", Time.elapsedTime())
        return pairs.sorted(by: { $0.0 < $1.0 })
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
    
    func moveToPos(from: Pos, pos: Pos) -> (Bool, [Move]) {
        guard let moves = Util.getMoves(from: from, to: pos) else {
            return (false, [])
        }
        performTemporaryMoves(moves: moves)
        return (true, moves)
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
                      // FIXME:
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
        guard Util.isAligned(connect.comp1.pos, connect.comp2.pos) else {
            fatalError()
        }
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
        guard Util.isAligned(connect.comp1.pos, connect.comp2.pos) else {
            fatalError()
        }
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
