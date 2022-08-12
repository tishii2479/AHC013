import OpenGL
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
        connectOneClusterMst(type: 1, evLimit: 5, costLimit: 5)
        connectOneClusterMst(type: 1, evLimit: 10, costLimit: 10)
        connectOneClusterMst(type: 2, evLimit: 5, costLimit: 5)
        connectOneClusterMst(type: 2, evLimit: 10, costLimit: 10)
//        connectOneClusterBfs(type: 2, evLimit: 10, costLimit: 10)
//        connectOneClusterBfs(type: 2, evLimit: 10, costLimit: 10)
        return (performedMoves, Array(connects))
    }
    
    func connectOneClusterBfs(type: Int, evLimit: Int = 100, costLimit: Int = 100) {
        let dist: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }

        let nearComputers = getNearCompPair(type: type, dist: dist)
        guard let startComp = field.computerGroup[type].randomElement() else {
            return
        }
        
        var q = Queue<Computer>()
        q.push(startComp)
        while let comp = q.pop() {
            guard let nearComps = nearComputers[comp] else {
                continue
            }
            for (evValue, nearComp) in nearComps {
                connectCompIfPossible(
                    comp1: comp, comp2: nearComp,
                    evValue: evValue, evLimit: evLimit, costLimit: costLimit
                )
            }
        }
    }
    
    func getNearCompPair(
        type: Int, dist: (Pos, Pos) -> Int, loopLimit: Int = 30
    ) -> [Computer: [(Int, Computer)]] {
        var ret = [Computer: [(Int, Computer)]]()
        for comp in field.computerGroup[type] {
            let nearComp = field.getNearComputers(aroundComp: comp, loopLimit: loopLimit, dist: dist)
            ret[comp] = nearComp
        }
        return ret
    }
    
    func connectOneClusterMst(type: Int, evLimit: Int = 100, costLimit: Int = 100) {
        let dist: (Pos, Pos) -> Int = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx
        }
        let compPair = getSortedCompPair(type: type, evLimit: evLimit, dist: dist)
        
        for (evValue, (comp1, comp2)) in compPair {
            connectCompIfPossible(
                comp1: comp1, comp2: comp2,
                evValue: evValue, evLimit: evLimit, costLimit: costLimit
            )
        }
    }
    
    private func connectCompIfPossible(
        comp1: Computer, comp2: Computer,
        evValue: Int, evLimit: Int, costLimit: Int
    ) {
        guard evValue <= evLimit else {
            return
        }
        guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
            return
        }
        var selectedMoves: [Move]? = nil
        var selectedMoveComp: Computer? = nil

        if let intersections = Util.intersections(comp1.pos, comp2.pos) {
            let currentCluster = field.getCluster(ofComputer: comp1).union(field.getCluster(ofComputer: comp2))
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
                        let newCluster = field.getCluster(ofComputer: comp1).union(field.getCluster(ofComputer: comp2))
                        let didSustainCluster = currentCluster.isSubset(of: newCluster)
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
        
        if let moves = selectedMoves {
            let cost = moves.count + 1
            // Check command limit
            let satisfyCommandLimit = currentCommands + cost <= field.computerTypes * 100
            let satisfyCostLimit = cost < costLimit
           if satisfyCommandLimit && satisfyCostLimit {
                performMoves(moves: moves)
                performConnect(connect: Connect(comp1: comp1, comp2: comp2), movedComp: selectedMoveComp)
           }
        }
    }
    
    private func getSortedCompPair(type: Int, evLimit: Int, dist: (Pos, Pos) -> Int) -> [(Int, (Computer, Computer))] {
        var compPair = [(Int, (Computer, Computer))]()
        for comp1 in field.computerGroup[type] {
            for comp2 in field.computerGroup[type] {
                guard comp1 != comp2 else { continue }
                
                let evValue = dist(comp1.pos, comp2.pos)
                if evValue < evLimit {
                    compPair.append((evValue, (comp1, comp2)))
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
