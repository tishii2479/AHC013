struct SolverV2 {
    let commander = BfsCommander()
    
    func search(beamWidth: Int = 4, candidate: Int = 4) {
        let eval = { (moves: Int, cableLength: Int) -> Int in
            return moves
        }

        var previousState = [State]()
        var nextState = [State]()
        for _ in 0 ..< 100 {
            // score, beamIndex, commands
            var evalNextCommands = [(Int, Int, [CommandV2])]()
            for b in 0 ..< previousState.count {
                let state = previousState[b]
                let currentScore = state.score
                for nextCommand in commander.commands(state: state, candidate: candidate) {
                    let scoreDiff = eval(nextCommand.count, 0)
                    evalNextCommands.append((scoreDiff + currentScore, b, nextCommand))
                }
            }
            evalNextCommands.sort(by: { $0.0 > $1.0 })
            for i in 0 ..< beamWidth {
                let (_, b, commands) = evalNextCommands[i]
                let state = previousState[b]
                state.snapshot()
                defer { state.rollback() }
                guard state.performCommands(commands: commands) else {
                    IO.log("Could not perform commands", type: .warn)
                }
                nextState.append(state.copy())
            }
            previousState = nextState
            nextState.removeAll()
        }
    }
}

protocol Commander {
    func commands(state: State, candidate: Int) -> [[CommandV2]]
}

struct BfsCommander: Commander {
    func commands(state: State, candidate: Int) -> [[CommandV2]] {
        guard let state = state as? BfsState else {
            fatalError()
        }
        var commands = [[CommandV2]]()

        state.snapshot()
        for _ in 0 ..< candidate {
            guard let comp = state.awaiting.randomElement() else {
                return commands
            }
            for newComp in nearComp(of: comp).random() {
                if state.cluster.contains(newComp) {
                    continue
                }
                defer { state.rollback() }
                guard let moves = movesToConnect(state, comp, newComp) else {
                    continue
                }
                commands.append(moves + [Connect(newComp, comp)])
            }
        }
        return commands
    }
}

class BfsState: State {
    var cluster: Cluster
    var awaiting: Set<Computer>
    
    init(score: Int, snapShotPoint: Int, field: FieldV2, commands: [CommandV2], moveSets: [MoveSet], connects: Set<Connect>, cluster: Cluster = Cluster(comps: Set<Computer>()), awaiting: Set<Computer> = Set<Computer>()) {
        super.init(
            score: score, snapShotPoint: snapShotPoint, field: field, commands: commands,
            moveSets: moveSets, connects: connects
        )
        self.cluster = Cluster(comps: Set<Computer>())
        self.awaiting = Set<Computer>()
    }
    
    override func performConnectIfPossible(comp1: Computer, comp2: Computer) -> Bool {
        if super.performConnectIfPossible(comp1: comp1, comp2: comp2) {
            if cluster.comps.contains(comp1) == cluster.comps.contains(comp2) {
                IO.log("\(comp1.pos), \(comp2.pos) are not merged, maybe something is going wrong", type: .warn)
            }
            cluster.comps.insert(comp1)
            cluster.comps.insert(comp2)
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

class MstState: State {
}

class State {
    var score: Int
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
