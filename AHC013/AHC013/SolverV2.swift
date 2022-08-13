struct SolverV2 {
    private let field: FieldV2
    private let commander: Commander
    
    init(field: FieldV2) {
        self.field = field
        self.commander = BfsCommander(compType: 1, distLimit: 5, computerGroup: field.computerGroup)
    }
    
    func solve(param: Parameter) -> ([Move], [Connect]) {
        search(compType: 1)
        return ([], [])
    }
    
    func search(compType: Int, beamWidth: Int = 4, candidate: Int = 4) {
        let eval = { (commands: Int, cableLength: Int) -> Int in
            return commands
        }

        var currentState = [State]()
        var nextState = [State]()
        
        let initialState = BfsState(score: 0, snapShotPoint: 0, field: field, commands: [], moveSets: [], connects: [])
        guard let startComp = field.computerGroup[compType].randomElement() else {
            return
        }
        initialState.cluster.add(comp: startComp)
        initialState.awaiting.insert(startComp)
        
        currentState.append(initialState)

        for i in 0 ..< 100 {
            IO.log(i)
            // score, beamIndex, commands
            var evalNextCommands = [(Int, Int, [CommandV2])]()
            for b in 0 ..< currentState.count {
                let state = currentState[b]
                let currentScore = state.score
                for nextCommand in commander.commands(state: state, candidate: candidate) {
                    let scoreDiff = eval(nextCommand.count, 0)
                    evalNextCommands.append((scoreDiff + currentScore, b, nextCommand))
                }
            }
            if evalNextCommands.isEmpty {
                IO.log("Could not raise cluster size")
                break
            }
            evalNextCommands.sort(by: { $0.0 > $1.0 })
            for i in 0 ..< min(evalNextCommands.count, beamWidth) {
                let (_, b, commands) = evalNextCommands[i]
                let state = currentState[b]
                state.snapshot()
                defer { state.rollback() }
                guard state.performCommands(commands: commands) else {
                    IO.log("Could not perform commands", type: .warn)
                    break
                }
                nextState.append(state.copy())
            }
            currentState = nextState
            nextState.removeAll()
        }
        
        guard let bestState = currentState.max(by: { (a, b) in a.score < b.score }) else {
            IO.log("Could not get best state.")
            return
        }
        bestState.field.dump()
        print(bestState.score)
        print(bestState.commands)
    }
}

protocol Commander {
    func commands(state: State, candidate: Int) -> [[CommandV2]]
}

struct BfsCommander: Commander {
    var nearComputers: [Computer: [Computer]]
    var compType: Int
    var distLimit: Int
    
    init(compType: Int, distLimit: Int, computerGroup: [Set<Computer>]) {
        self.compType = compType
        self.distLimit = distLimit
        self.nearComputers = BfsCommander.getNearComputers(type: compType, distF: Util.distF, distLimit: distLimit, computerGroup: computerGroup)
    }
    
    func commands(state: State, candidate: Int) -> [[CommandV2]] {
        guard let state = state as? BfsState else {
            fatalError()
        }
        var candidates = [[CommandV2]]()

        state.snapshot()
        for _ in 0 ..< candidate {
            guard let comp = state.awaiting.randomElement() else {
                return candidates
            }
            guard let newComp = nearComputers[comp]?.last else {
                continue
            }
            IO.log(comp.pos, newComp.pos)
            if state.cluster.comps.contains(newComp) {
                continue
            }
            defer { state.rollback() }
            guard let commands = commandsToConnect(state: state, comp1: comp, comp2: newComp) else {
                continue
            }
            candidates.append(commands + [Connect(comp1: newComp, comp2: comp)])
        }
        return candidates
    }
    
    func commandsToConnect(state: State, comp1: Computer, comp2: Computer) -> [CommandV2]? {
        var commands = [CommandV2]()
        
        let intersections = [Pos(x: comp1.pos.x, y: comp2.pos.y), Pos(x: comp2.pos.x, y: comp1.pos.y)]

        for (moveComp, targetComp) in [(comp1, comp2), (comp2, comp1)] {
            for inter in intersections {
                defer { state.rollback() }
                // check no cables between inter and targetComp2.pos
                let ignorePos = [moveComp.pos] + Util.getBetweenPos(from: moveComp.pos, to: inter) + [inter] +
                Util.getBetweenPos(from: inter, to: targetComp.pos) + [targetComp.pos]
                let fixedComp = [moveComp, targetComp]
                
                if moveComp.pos != inter {
                    // move moveComp to inter
                    guard state.field.canMoveComputer(to: inter, compType: moveComp.type) else {
                        continue
                    }
                    guard let movesToInter = commandsToMove(state: state, comp: moveComp, to: inter, ignorePos: ignorePos, fixedComp: fixedComp) else {
                        continue
                    }
                    commands.append(contentsOf: movesToInter)
                }
                // moves to clear inter to targetComp
                guard let movesToClear = movesToClear(state: state, from: inter, to: targetComp.pos, ignorePos: ignorePos, fixedComp: fixedComp) else {
                    continue
                }
                commands.append(contentsOf: movesToClear)

                return commands
            }
        }
        return nil
    }
    
    func commandsToMove(state: State, comp: Computer, to: Pos, ignorePos: [Pos], fixedComp: [Computer]) -> [CommandV2]? {
        var commands = [CommandV2]()
        let moveToTarget = MoveSet.aligned(comp: comp, to: to)
        guard state.performMoveSetIfPossible(moveSet: moveToTarget),
              let movesToClear = movesToClear(state: state, from: comp.pos, to: to, ignorePos: ignorePos, fixedComp: fixedComp) else {
            return nil
        }
        commands.append(moveToTarget)
        commands.append(contentsOf: movesToClear)
        return commands
    }
    
    private func movesToClear(state: State, from: Pos, to: Pos, ignorePos: [Pos], fixedComp: [Computer]) -> [CommandV2]? {
        guard from != to else { return [] }
        var commands = [CommandV2]()
        for pos in Util.getBetweenPos(from: from, to: to) {
            if state.field.cell(pos: pos).isComputer {
                guard let emptyPos = state.field.findNearestEmptyCell(at: pos, ignorePos: ignorePos) else {
                    return nil
                }
                guard let movesToEmpty = movesToEmptyCell(state: state, from: pos, to: emptyPos, fixedComp: fixedComp) else {
                    return nil
                }
                for moveSet in movesToEmpty {
                    guard state.performMoveSetIfPossible(moveSet: moveSet) else {
                        return nil
                    }
                }
                commands.append(contentsOf: movesToEmpty)
            }
        }
        return commands
    }
    
    private func movesToEmptyCell(state: State, from: Pos, to: Pos, fixedComp: [Computer], trialLimit: Int = 20) -> [MoveSet]? {
        var dirs = Util.dirsForPath(from: from, to: to)
        
        // TODO: select optimal order
        
        for _ in 0 ..< trialLimit {
            dirs.shuffle()

            var cPos: Pos = from
            var disallowedMove = false
            var ret = [MoveV2]()
            
            for dir in dirs {
                guard let comp = state.field.cell(pos: cPos).computer,
                      // Cable won't extend automatically,
                      // so another computer may come on the extended cable
                      // instead of `comp.isMovable(dir: dir)`
                      !comp.isConnected,
                      !fixedComp.contains(comp),
                      !state.field.hasConflictedCable(at: cPos) else {
                    disallowedMove = true
                    break
                }
                ret.append(MoveV2(comp: comp, dir: dir))
                cPos += dir
            }
            
            if !disallowedMove {
                return MoveSet.fromMixedMoves(moves: ret.reversed())
            }
        }
            
        return nil
    }
    
    static func getNearComputers(
        type: Int, distF: (Pos, Pos) -> Int, distLimit: Int,
        computerGroup: [Set<Computer>]
    ) -> [Computer: [Computer]] {
        var ret = [Computer: [Computer]]()
        for comp1 in computerGroup[type] {
            ret[comp1] = []
            for comp2 in computerGroup[type] {
                guard comp1 != comp2 else { continue }
                let dist = distF(comp1.pos, comp2.pos)
                if dist <= distLimit {
                    ret[comp1]?.append(comp2)
                }
            }
            ret[comp1]?.sort(by: { comp1.pos.dist(to: $0.pos) < comp1.pos.dist(to: $1.pos) })
        }
        return ret
    }
}

class BfsState: State {
    var cluster: Cluster
    var awaiting: Set<Computer>
    
    init(
        score: Int, snapShotPoint: Int, field: FieldV2, commands: [CommandV2],
        moveSets: [MoveSet], connects: Set<Connect>,
        cluster: Cluster? = nil,
        awaiting: Set<Computer>? = nil
    ) {
        self.cluster = cluster ?? Cluster(comps: [])
        self.awaiting = awaiting ?? []
        super.init(
            score: score, snapShotPoint: snapShotPoint, field: field, commands: commands,
            moveSets: moveSets, connects: connects
        )
    }
    
    override func performConnectIfPossible(comp1: Computer, comp2: Computer) -> Bool {
        if super.performConnectIfPossible(comp1: comp1, comp2: comp2) {
            if cluster.comps.contains(comp1) == cluster.comps.contains(comp2) {
                IO.log("\(comp1.pos), \(comp2.pos) are not merged, maybe something is going wrong", type: .warn)
            }
            if cluster.comps.contains(comp1) {
                cluster.comps.insert(comp2)
                awaiting.insert(comp2)
            }
            else {
                cluster.comps.insert(comp1)
                awaiting.insert(comp1)
            }
            return true
        }
        return false
    }
    
    override func copy() -> State {
        BfsState(
            score: score, snapShotPoint: snapShotPoint, field: field, commands: commands,
            moveSets: moveSets, connects: connects, cluster: cluster, awaiting: awaiting
        )
    }
}

class State {
    private(set) var score: Int
    private(set) var snapShotPoint: Int
    let field: FieldV2

    private(set) var commands: [CommandV2]

    private(set) var moveSets: [MoveSet]
    private(set) var connects: Set<Connect>

    init(score: Int, snapShotPoint: Int, field: FieldV2, commands: [CommandV2], moveSets: [MoveSet], connects: Set<Connect>) {
        self.score = score
        self.snapShotPoint = snapShotPoint
        self.field = field
        self.commands = commands
        self.moveSets = moveSets
        self.connects = connects
    }
    
    func performCommands(commands: [CommandV2]) -> Bool {
        for command in commands {
            if let moveSet = command as? MoveSet {
                guard performMoveSetIfPossible(moveSet: moveSet) else {
                    return false
                }
            }
            else if let connect = command as? Connect {
                guard performConnectIfPossible(comp1: connect.comp1, comp2:  connect.comp2) else {
                    return false
                }
            }
            else {
                fatalError()
            }
        }
        return true
    }

    func performConnectIfPossible(comp1: Computer, comp2: Computer) -> Bool {
        guard field.canPerformConnect(comp1: comp1, comp2: comp2) else {
            return false
        }
        let connect = Connect(comp1: comp1, comp2: comp2)
        connects.insert(connect)
        field.performConnect(comp1: comp1, comp2: comp2)
        return true
    }

    func eraseConnect(connect: Connect) {
        connects.remove(connect)
        field.eraseConnect(comp1: connect.comp1, comp2: connect.comp2)
    }

    func performMoveSetIfPossible(moveSet: MoveSet) -> Bool {
        guard field.canPerformMoveSet(moveSet: moveSet) else {
            return false
        }
        moveSets.append(moveSet)
        field.performMoveSet(moveSet: moveSet)
        return true
    }

    func snapshot() {
        snapShotPoint = commands.count
    }

    func rollback() {
        guard commands.count >= snapShotPoint else {
            fatalError()
        }
        while commands.count > snapShotPoint {
            guard let command = commands.popLast() else {
                fatalError()
            }
            if command is MoveSet {
                popLastMoveSet()
            }
            else if let connect = command as? Connect {
                eraseConnect(connect: connect)
            }
            else {
                fatalError()
            }
        }
    }

    func popLastMoveSet() {
        guard let moveSet = moveSets.popLast() else {
            fatalError()
        }
        field.reverseMoveSet(moveSet: moveSet)
    }
    
    func copy() -> State {
        State(
            score: score, snapShotPoint: snapShotPoint, field: field, commands: commands,
            moveSets: moveSets, connects: connects
        )
    }
}
