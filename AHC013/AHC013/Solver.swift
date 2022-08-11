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
        IO.log(moves, connects)
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
            if evValue > 2 {
                break
            }
            IO.log(evValue, comp1.pos, comp2.pos)
            guard !field.isInSameCluster(comp1: comp1, comp2: comp2) else {
                continue
            }
            
            var selectedMoves: [Move]? = nil

            if let intersections = Util.intersections(comp1.pos, comp2.pos) {
                IO.log(intersections, type: .debug)
                for (fromComp, toComp) in [(comp1, comp2), (comp2, comp1)] {
                    for inter in intersections {
                        guard checkConnectable(from: inter, to: toComp.pos, compType: toComp.type),
                              let moves1 = movesToClear(from: fromComp.pos, to: inter, addEnd: true),
                              let moves2 = movesToClear(from: inter, to: toComp.pos) else {
                            continue
                        }

                        let moves = moves1 + moves2
                        if selectedMoves == nil || moves.count < selectedMoves!.count {
                            selectedMoves = moves
                        }
                    }
                }
            }
            else {
                // is already aligned
                IO.log(checkConnectable(from: comp1.pos, to: comp2.pos, compType: comp1.type), type: .debug)
                IO.log(movesToClear(from: comp1.pos, to: comp2.pos, addEnd: true), type: .debug)
                guard checkConnectable(from: comp1.pos, to: comp2.pos, compType: comp1.type),
                      let moves = movesToClear(from: comp1.pos, to: comp2.pos, addEnd: true) else {
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
            IO.log(move.pos, move.pos + move.dir, type: .debug)
            moves.append(move)
            field.performMove(move: move)
        }
        else if let connect = command as? Connect {
            IO.log(connect.comp1.pos, connect.comp2.pos, type: .debug)
            connects.append(connect)
            field.performConnect(connect: connect)
        }
    }
    
    private func movesToClear(from: Pos, to: Pos, addEnd: Bool = false) -> [Move]? {
        let path = Util.getBetweenPos(from: from, to: to, addEnd: addEnd)
        var moves = [Move]()

        for pos in path {
            guard field.cell(pos: pos).isComputer else { continue }
            
            guard let emptyPos = field.findNearestEmptyCell(pos: pos, ignorePos: path) else {
                IO.log("Could not find empty cell")
                return nil
            }

            moves.append(contentsOf: movesToEmptyCell(from: pos, to: emptyPos))
        }

        return moves
    }
    
    private func movesToEmptyCell(from: Pos, to: Pos) -> [Move] {
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
            dirs.append(contentsOf: [Dir](repeating: .left, count: abs(dy)))
        }
        else if dx > 0 {
            dirs.append(contentsOf: [Dir](repeating: .right, count: abs(dy)))
        }
        
        // TODO: select optimal order
        dirs.shuffle()

        var cPos: Pos = from
        var ret = [Move]()
        
        for dir in dirs {
            ret.append(Move(pos: cPos, dir: dir))
            cPos += dir
        }
        
        return ret.reversed()
    }
}
