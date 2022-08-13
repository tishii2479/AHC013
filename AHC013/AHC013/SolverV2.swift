struct SolverV2 {
    private let field: FieldV2
    private let commander: Commander
    
    init(field: FieldV2) {
        self.field = field
        self.commander = BfsCommander(compType: 1, distLimit: 5, computerGroup: field.computerGroup)
    }
    
    func solve(param: Parameter) -> ([Move], [Connect]) {
        ([], [])
    }
    
    func search(compType: Int, beamWidth: Int = 4, candidate: Int = 4) {
        let eval = { (commands: Int, cableLength: Int) -> Int in
            return commands
        }

        var currentState = [State]()
        var nextState = [State]()
        
        let initialState = State(score: 0, snapShotPoint: 0, field: field, commands: [], moveSets: [], connects: [])
        
        currentState.append(initialState)

        for _ in 0 ..< 100 {
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
            evalNextCommands.sort(by: { $0.0 > $1.0 })
            for i in 0 ..< beamWidth {
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
    }
}

protocol Commander {
    func commands(state: State, candidate: Int) -> [[CommandV2]]
}

struct BfsCommander: Commander {
    var nearComputers: [Computer: Set<Computer>]
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
            guard let newComp = nearComputers[comp]?.randomElement() else {
                continue
            }
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
        return nil
    }
    
    static func getNearComputers(
        type: Int, distF: (Pos, Pos) -> Int, distLimit: Int,
        computerGroup: [Set<Computer>]
    ) -> [Computer: Set<Computer>] {
        var ret = [Computer: Set<Computer>]()
        for comp1 in computerGroup[type] {
            ret[comp1] = Set<Computer>()
            for comp2 in computerGroup[type] {
                guard comp1 != comp2 else { continue }
                let dist = distF(comp1.pos, comp2.pos)
                if dist <= distLimit {
                    ret[comp1]?.insert(comp2)
                }
            }
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

class MstState: State {
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
