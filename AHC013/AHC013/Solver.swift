protocol Solver {
    init(field: Field)
    func solve()
}

class SolverV1 {
    private let field: Field
    private var moves: [Move] = []
    private var connects: [Connect] = []

    init(field: Field) {
        self.field = field
    }

    func solve() -> ([Move], [Connect]) {
        connectOneCluster(type: 1)
        return (moves, connects)
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
        
        for (evValue, (comp1, comp2)) in distPair {
            guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
                IO.log("Same cluster", comp1.pos, comp2.pos)
                continue
            }
            
            var selectedMoves: [Move]? = nil

            if let intersections = Util.intersections(comp1.pos, comp2.pos) {
                for (fromComp, toComp) in [(comp1, comp2), (comp2, comp1)] {
                    guard !fromComp.isFixed else {
                        continue
                    }
                    for inter in intersections {
                        let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: inter) + [inter] +
                            Util.getBetweenPos(from: inter, to: comp2.pos) + [comp2.pos]
                        guard checkConnectable(from: inter, to: toComp.pos, compType: toComp.type),
                              let moves1 = movesToClear(from: fromComp.pos, to: inter, ignorePos: ignorePos, addEnd: true),
                              let moveToInter = Util.getMoves(from: fromComp.pos, to: inter),
                              let moves2 = movesToClear(from: inter, to: toComp.pos, ignorePos: ignorePos) else {
                            continue
                        }

                        let moves = moves1 + moveToInter + moves2
                        if selectedMoves == nil || moves.count < selectedMoves!.count {
                            selectedMoves = moves
                        }
                    }
                }
            }
            else {
                // is already aligned
                let ignorePos = [comp1.pos] + Util.getBetweenPos(from: comp1.pos, to: comp2.pos) + [comp2.pos]
                guard checkConnectable(from: comp1.pos, to: comp2.pos, compType: comp1.type),
                      let moves = movesToClear(from: comp1.pos, to: comp2.pos, ignorePos: ignorePos) else {
                    continue
                }
                selectedMoves = moves
            }
            
            if let moves = selectedMoves {
                for move in moves {
                    performCommand(command: move)
                }
                performCommand(command: Connect(comp1: comp1, comp2: comp2))
            }
        }
    }
    
    private func checkConnectable(from: Pos, to: Pos, compType: Int) -> Bool {
        guard let dir = Util.toDir(from: from, to: to) else {
            return false
        }
        let direction = Util.fromDir(dir: dir)
        let allowedCable = Cable(compType: compType, direction: direction)
        return !field.hasCable(from: from, to: to, allowedCable: allowedCable)
    }
    
    private func performCommand(command: Command) {
        if let move = command as? Move {
            moves.append(move)
            field.performMove(move: move)
        }
        else if let connect = command as? Connect {
            connects.append(connect)
            field.performConnect(connect: connect)
        }
    }
    
    func movesToClear(from: Pos, to: Pos, ignorePos: [Pos], addEnd: Bool = false) -> [Move]? {
        let path = Util.getBetweenPos(from: from, to: to, addEnd: addEnd)
        var moves = [Move]()
        for pos in path {
            guard field.cell(pos: pos).isComputer else { continue }
            
            guard let emptyPos = field.findNearestEmptyCell(pos: pos, ignorePos: ignorePos) else {
                IO.log("Could not find empty cell", type: .warn)
                return nil
            }
            
            guard let movesToEmpty = movesToEmptyCell(from: pos, to: emptyPos) else {
                return nil
            }
            
            IO.log(pos, emptyPos, movesToEmpty, path + [from, to])
            moves.append(contentsOf: movesToEmpty)
        }
        return moves
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
                if field.cell(pos: cPos).isCabled {
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
}
