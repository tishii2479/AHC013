protocol Solver {
    init(field: Field)
    func solve()
}

class SolverV1 {
    private let field: Field
    private var performedMoves: [Move] = []
    private var connects = Set<Connect>()
    private var temporaryMoves: [Move] = []

    init(field: Field) {
        self.field = field
    }

    func solve() -> ([Move], [Connect]) {
        connectOneCluster(type: 1)
        return (performedMoves, Array(connects))
    }
    
    func connectOneCluster(type: Int) {
        var distPair = [(Int, (Computer, Computer))]()
        
        let dist = { (a: Pos, b: Pos) -> Int in
            let dy = abs(b.y - a.y)
            let dx = abs(b.x - a.x)
            return dy + dx + dy * dx
        }
        
        for comp1 in field.computerGroup[type] {
            for comp2 in field.computerGroup[type] {
                guard comp1 != comp2 else { continue }
                
                let evValue = dist(comp1.pos, comp2.pos)
                distPair.append((evValue, (comp1, comp2)))
            }
        }
        
        distPair.sort(by: { (a, b) in
            return a.0 < b.0
        })
        
        for (_, (comp1, comp2)) in distPair {
            guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
                continue
            }
            
            var selectedMoves: [Move]? = nil
            var selectedMoveComp: Computer? = nil

            if let intersections = Util.intersections(comp1.pos, comp2.pos) {
                let currentCluster = field.getCluster(ofComputer: comp1).union(field.getCluster(ofComputer: comp2))
                for (fromComp, toComp) in [(comp1, comp2), (comp2, comp1)] {
//                    guard !fromComp.isFixed else { continue }
                    for inter in intersections {
                        let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: inter) + [inter] +
                            Util.getBetweenPos(from: inter, to: comp2.pos) + [comp2.pos]
                        if let dir = Util.toDir(from: fromComp.pos, to: inter) {
                            if !fromComp.isMovable(dir: dir) {
                                continue
                            }
                            if fromComp.hasConnectedComp(to: dir.rev),
                               !checkConnectable(from: fromComp.pos, to: inter, compType: toComp.type) {
                                continue
                            }
                        }
                        if checkConnectable(from: inter, to: toComp.pos, compType: toComp.type),
                           let moves1 = movesToClear(from: fromComp.pos, to: inter, ignorePos: ignorePos, addEnd: true),
                           let moveToInter = moveToInter(from: fromComp.pos, inter: inter),
                           let moves2 = movesToClear(from: inter, to: toComp.pos, ignorePos: ignorePos) {
                            let moves = moves1 + moveToInter + moves2
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
                   let moves = movesToClear(from: comp1.pos, to: comp2.pos, ignorePos: ignorePos) {
                    selectedMoves = moves
                }
                reverseTemporaryMoves()
            }
            
            if let moves = selectedMoves {
                performMoves(moves: moves)
                performConnect(connect: Connect(comp1: comp1, comp2: comp2), movedComp: selectedMoveComp)
            }
        }
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
//        IO.log(from, to, compType, val)
        return val
    }
    
    func moveToInter(from: Pos, inter: Pos) -> [Move]? {
        guard let interMoves = Util.getMoves(from: from, to: inter) else {
            return nil
        }
        performTemporaryMoves(moves: interMoves)
        return interMoves
    }
    
    func movesToClear(from: Pos, to: Pos, ignorePos: [Pos], addEnd: Bool = false) -> [Move]? {
        let path = Util.getBetweenPos(from: from, to: to, addEnd: addEnd)
        var clearMoves = [Move]()
        for pos in path {
            guard field.cell(pos: pos).isComputer else { continue }
            
            guard let emptyPos = field.findNearestEmptyCell(pos: pos, ignorePos: ignorePos) else {
//                IO.log("Could not find empty cell")
                return nil
            }
            
            guard let movesToEmpty = movesToEmptyCell(from: pos, to: emptyPos) else {
                return nil
            }

            performTemporaryMoves(moves: movesToEmpty)
            clearMoves.append(contentsOf: movesToEmpty)
        }
        return clearMoves
    }
    
    func movesToEmptyCell(from: Pos, to: Pos, trialLimit: Int = 20) -> [Move]? {
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
                if let comp = field.cell(pos: cPos).computer,
                   comp.isFixed {
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
