protocol Solver {
    init(field: Field)
}

final class SolverV1: Solver {
    let field: Field
    private(set) var performedMoves: [Move] = []
    private(set) var connects = Set<Connect>()
    private var temporaryMoves: [Move] = []
    private var mainType: Int = 0
    
    private var currentCommands: Int {
        performedMoves.count + connects.count
    }

    init(field: Field) {
        self.field = field
    }
    
    init(field: Field, performedMoves: [Move], connects: Set<Connect>) {
        self.field = field
        self.performedMoves = performedMoves
        self.connects = connects
    }

    func constructFirstCluster(type: Int, param: Parameter) -> (Int, Int) {
        mainType = type
        IO.log("constructFirstCluster:1", Time.elapsedTime(), type: .log)
        connectOneClusterMst(type: type, distLimit: param.distLimit, costLimit: param.costLimit)
        IO.log("constructFirstCluster:2", Time.elapsedTime(), type: .log)
        connectOneClusterMst(type: type, distLimit: param.distLimit * 2, costLimit: param.costLimit * 2)
        IO.log("constructFirstCluster:3", Time.elapsedTime(), type: .log)
        connectOneClusterWithOtherComputer(type: type)
        IO.log("constructFirstCluster:4", Time.elapsedTime(), type: .log)
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
    
    func connectOneClusterWithOtherComputer(
        type: Int, otherCompLimit: Int = 1,
        distLimit: Int = 4, costLimit: Int = 10
    ) {
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }

        let compPair = getSortedCompPair(type: type, distLimit: distLimit, distF: distF)
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
            var newCluster = cluster1.merge(cluster2)
            var bestConnects = [Connect]()
            var bestMoves = [Move]()
            var bestImprovedScore = 0
            
            for pos1 in field.movable(comp: comp1, moveLimit: 3) {
                for pos2 in field.movable(comp: comp2, moveLimit: 3) {
                    guard Time.isInTime() else { return }
                    guard pos1 != pos2 else { continue }
                    var cPos = pos1
                    var cComp = comp1
                    var ok = true
                    var tempConnects = [Connect]()
                    var connectedComps = [Computer]()
                        
                    // TODO: find optimal
                    // FIXME: make it possible to connect between empty cells
                    
                    for dir in Util.dirsForPath(from: pos1, to: pos2) {
                        let nextPos = cPos + dir
                        guard nextPos != comp1.pos,
                              let comp = field.cell(pos: nextPos).computer else {
                            ok = false
                            break
                        }
                        connectedComps.append(comp)
                        tempConnects.append(Connect(comp1: cComp, comp2: comp))
                        cComp = comp
                        cPos += dir
                    }
                    guard ok else { continue }
                    
                    let newComputerTypes = connectedComps.filter{ $0.type != comp1.type }.map{ $0.type }
                    let improvedScore = newCluster.getScore(addTypes: newComputerTypes) - currentScore
                    if let moves1 = Util.getMoves(from: comp1.pos, to: pos1),
                       let moves2 = Util.getMoves(from: comp2.pos, to: pos2),
                       improvedScore > bestImprovedScore && currentCommands + moves1.count + moves2.count + tempConnects.count <= field.computerTypes * 100 {
                        bestImprovedScore = improvedScore
                        bestConnects = tempConnects
                        bestMoves = moves1 + moves2
                    }
                }
            }
            
            if bestImprovedScore > 0 {
                performMoves(moves: bestMoves)
                for connect in bestConnects {
                    performConnect(connect: connect)
                }
            }
        }
    }
    
    func connectOneClusterBfs(types: [Int], distLimit: Int = 100, costLimit: Int = 100, trialLimit: Int = 30) {
        guard Time.isInTime() else { return }
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }
        
        // TODO: cache?
        let nearComputers = getNearCompPair(types: types, distF: distF, distLimit: distLimit)
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
            let reachableComps = field.getNearComputers(aroundComp: startComp, loopLimit: field.size * field.size, distF: distF)
            if reachableComps.count > largestClusterSize {
                largestClusterSize = reachableComps.count
                largestStartComp = startComp
            }
        }
//        IO.log("connectOneClusterBfs:searchStartComp:end", Time.elapsedTime())
        
        guard let startComp = largestStartComp else {
            return
        }
        
        IO.log("Selected:", startComp.type, startComp.pos, largestClusterSize)
        
        var q = Queue<Computer>()
        q.push(startComp)
        while let comp = q.pop() {
            guard Time.isInTime() else { return }
            guard let nearComps = nearComputers[comp] else {
                continue
            }
            for (dist, nearComp) in nearComps {
                guard Time.isInTime() else { return }
                let connected = connectCompIfPossible(
                    comp1: comp, comp2: nearComp,
                    dist: dist, distLimit: distLimit, costLimit: costLimit,
                    reconnectIfPossible: true
                )
                if connected {
                    q.push(nearComp)
                }
            }
        }
    }
    
    // TODO: change process
    // ISSUE: slow
    func getNearCompPair(
        types: [Int], distF: (Pos, Pos) -> Int,
        distLimit: Int
    ) -> [Computer: [(Int, Computer)]] {
        IO.log("getNearCompPair:start", Time.elapsedTime())
        var ret = [Computer: [(Int, Computer)]]()
        for type in types {
            for comp in field.computerGroup[type] {
                let nearComp = field.getNearComputers(
                    aroundComp: comp,
                    loopLimit: 100,
                    distF: distF
                )
                ret[comp] = nearComp
            }
        }
        IO.log("getNearCompPair:end", Time.elapsedTime())
        return ret
    }
    
    // ISSUE: slow
    // TODO: change process
    // Not used
    func getNearCompPair2(
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
                ret[comp1]?.append((dist, comp2))
                ret[comp2]?.append((dist, comp1))
            }
        }
        IO.log("getNearCompPair:end", Time.elapsedTime())
        return ret
    }
    
    func connectOneClusterMst(type: Int, distLimit: Int = 100, costLimit: Int = 100) {
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx + Int.random(in: -2 ... 2)
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
    
    // Returns true if connected
    private func connectCompIfPossible(
        comp1: Computer, comp2: Computer,
        dist: Int, distLimit: Int, costLimit: Int,
        reconnectIfPossible: Bool = false,
        blockedPos: [Pos] = []
    ) -> Bool {
        guard dist <= distLimit else {
            return false
        }
        guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
            return false
        }
        var selectedMoves: [Move]? = nil
        var selectedMoveComp: Computer? = nil

        var reconnectConnects: (Connect, Connect)? = nil
        
        let currentScore = field.getCluster(ofComputer: comp1).calcScore()
            + field.getCluster(ofComputer: comp2).calcScore()

        if let intersections = Util.intersections(comp1.pos, comp2.pos) {
            for (fromComp, toComp) in [(comp1, comp2), (comp2, comp1)] {
                for inter in intersections {
                    let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: inter) + [inter] +
                        Util.getBetweenPos(from: inter, to: comp2.pos) + [comp2.pos] + blockedPos
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
                    if reconnectIfPossible,
                       !checkConnectable(from: inter, to: toComp.pos, compType: toComp.type) {
                        reconnectConnects = reconnectClusterIfPossible(
                            from: inter, to: toComp.pos, compType: toComp.type)
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
                        let didImprovedMoves = selectedMoves == nil || moves.count < selectedMoves!.count
                        let newCluster = field.getCluster(ofComputer: comp1).merge(field.getCluster(ofComputer: comp2))
                        let didImproveScore = newCluster.calcScore() > currentScore
                        if didImprovedMoves && didImproveScore {
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
            let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: comp2.pos)
                                + [comp2.pos] + blockedPos
            if reconnectIfPossible,
               !checkConnectable(from: comp1.pos, to: comp2.pos, compType: comp1.type) {
                reconnectConnects = reconnectClusterIfPossible(
                    from: comp1.pos, to: comp2.pos, compType: comp2.type)
            }
            if checkConnectable(from: comp1.pos, to: comp2.pos, compType: comp1.type),
               let moves = movesToClear(from: comp1.pos, to: comp2.pos,
                                        ignorePos: ignorePos, fixedComp: [comp1, comp2]) {
                let newCluster = field.getCluster(ofComputer: comp1).merge(field.getCluster(ofComputer: comp2))
                let didImproveScore = newCluster.calcScore() > currentScore
                if didImproveScore {
                    selectedMoves = moves
                }
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

    private func reconnectClusterIfPossible(from: Pos, to: Pos, compType: Int) -> (Connect, Connect)? {
        // check cables between from and pos
        var existingCable: Cable? = nil
        for pos in Util.getBetweenPos(from: from, to: to) {
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
        
        guard let existingCable = existingCable else {
//            IO.log("I think there should be a cable between \(from) and \(to)", type: .warn)
            return nil
        }
        
        return findReconnection(
            comp1: existingCable.comp1, comp2: existingCable.comp2,
            ignorePos: Util.getBetweenPos(from: from, to: to)
        )
    }
    
    private func findReconnection(
        comp1: Computer, comp2: Computer,
        ignorePos: [Pos]
    ) -> (Connect, Connect)? {
        let distF: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }
        
        var reconnected = false
        // reset connect temporary
        let connect = Connect(comp1: comp1, comp2: comp2)
        resetConnect(connect: connect)
        defer {
            if !reconnected {
                // reset
                performConnect(connect: connect)
            }
        }
        
        let cluster1 = field.getCluster(ofComputer: comp1)
        let cluster2 = field.getCluster(ofComputer: comp2)

        for compInCluster1 in cluster1.comps {
            for compInCluster2 in cluster2.comps {
                guard !(comp1 == compInCluster1 && comp2 == compInCluster2) else {
                    continue
                }
                guard Util.isAligned(compInCluster1.pos, compInCluster2.pos) else {
                    continue
                }
                var doesIntersect: Bool = false
                let dist = distF(compInCluster1.pos, compInCluster2.pos)
                // check if the new cable is not on ignorePos
                for pos in Util.getBetweenPos(from: compInCluster1.pos, to: compInCluster2.pos) {
                    if ignorePos.contains(pos) || field.cell(pos: pos).isComputer {
                        doesIntersect = true
                        break
                    }
                }
                guard !doesIntersect else {
                    continue
                }
                if connectCompIfPossible(
                    comp1: compInCluster1, comp2: compInCluster2, dist: dist,
                    distLimit: 100, costLimit: 100, blockedPos: ignorePos
                ) {
                    IO.log("reconnected: (\(comp1.pos), \(comp2.pos)) -> (\(compInCluster1.pos), \(compInCluster2.pos))")
                    reconnected = true
                    return (Connect(comp1: comp1, comp2: comp2),
                            Connect(comp1: compInCluster1, comp2: compInCluster2))
                }
            }
        }
        return nil
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
        var dirs = Util.dirsForPath(from: from, to: to)
        
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
            field.performMove(move: move, isTemporary: true)
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
