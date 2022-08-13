import Foundation

let startDate = Date()

func elapsedTime() -> Double {
    Date().timeIntervalSince(startDate)
}

func isInTime() -> Bool {
    elapsedTime() < 2.7
}

class Computer {
    var id: Int
    var type: Int
    var pos: Pos
    var connected = Set<Computer>()
    
    init(id: Int, type: Int, pos: Pos) {
        self.id = id
        self.type = type
        self.pos = pos
    }
    
    var isConnected: Bool {
        connected.count > 0
    }
    
    func isMovable(dir: Dir) -> Bool {
        let direction = Util.fromDir(dir: dir)
        for comp in connected {
            if let connectedDir = Util.toDir(from: pos, to: comp.pos),
               direction != Util.fromDir(dir: connectedDir) {
                return false
            }
        }
        return true
    }
    
    func isConnected(to comp: Computer) -> Bool {
        connected.contains(comp)
    }
    
    func connectedComp(to dir: Dir) -> Computer? {
        for comp in connected {
            if let compDir = Util.toDir(from: pos, to: comp.pos),
               dir == compDir {
                return comp
            }
        }
        return nil
    }
}

extension Computer: Equatable {
    static func == (lhs: Computer, rhs: Computer) -> Bool {
        lhs.id == rhs.id
    }
}

extension Computer: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Cluster {
    var comps: Set<Computer>
    var typeCounts: [Int]
    
    init(comps: Set<Computer>, types: Int = 5) {
        self.comps = Set<Computer>()
        typeCounts = [Int](repeating: 0, count: types + 1)
        for comp in comps {
            add(comp: comp)
        }
    }
    
    mutating func getScore(addType: Int) -> Int {
        getScore(addTypes: [addType])
    }
    
    mutating func getScore(addTypes: [Int]) -> Int {
        // calc temporary
        for type in addTypes {
            typeCounts[type] += 1
        }
        let newScore = calcScore()
        for type in addTypes {
            typeCounts[type] -= 1
        }
        return newScore
    }
    
    func calcScore() -> Int {
        var score = 0
        for i in 1 ..< typeCounts.count {
            for j in 1 ... i {
                if i == j {
                    score += typeCounts[i] * (typeCounts[i] - 1) / 2
                }
                else {
                    score -= typeCounts[i] * typeCounts[j]
                }
            }
        }
        return score
    }
    
    func merge(_ other: Cluster) -> Cluster {
        var ret = self
        for comp in other.comps {
            ret.add(comp: comp)
        }
        return ret
    }
    
    mutating func add(comp: Computer) {
        if !comps.contains(comp) {
            typeCounts[comp.type] += 1
        }
        comps.insert(comp)
    }
}

enum Direction {
    case horizontal
    case vertical
}

struct Cable {
    var compType: Int
    var direction: Direction
    var comp1: Computer
    var comp2: Computer
}

extension Cable {
    static func == (lhs: Cable, rhs: Cable) -> Bool {
        lhs.compType == rhs.compType && lhs.direction == rhs.direction
    }

    static func != (lhs: Cable, rhs: Cable) -> Bool {
        !(lhs == rhs)
    }
}

enum Dir {
    case left
    case up
    case right
    case down

    static let all: [Dir] = [
        .left, .up, .right, .down
    ]
    
    var pos: Pos {
        switch self {
        case .left:
            return Pos(x: -1, y: 0)
        case .up:
            return Pos(x: 0, y: -1)
        case .right:
            return Pos(x: 1, y: 0)
        case .down:
            return Pos(x: 0, y: 1)
        }
    }
    
    var rev: Dir {
        switch self {
        case .left:
            return .right
        case .up:
            return .down
        case .right:
            return .left
        case .down:
            return .up
        }
    }
}

protocol Command {
    var outValue: String { get }
}

protocol CommandV2 {
}

struct MoveSet: CommandV2 {
    var comp: Computer
    var moves: [MoveV2]
    
    init(comp: Computer, moves: [MoveV2]) {
        self.comp = comp
        self.moves = moves
    }
    
    init(comp: Computer, dirs: [Dir]) {
        self.comp = comp
        self.moves = dirs.map { MoveV2(comp: comp, dir: $0 )}
    }
    
    var to: Pos {
        let path = path()
        return path[path.count - 1]
    }
    
    // include end
    func path() -> [Pos] {
        var ret = [Pos]()
        var cPos = comp.pos
        for move in moves {
            ret.append(cPos + move.dir)
            cPos += move.dir
        }
        return ret
    }
    
    func rev() -> MoveSet {
        var ret = self
        ret.moves = ret.moves.reversed().map { $0.rev() }
        return ret
    }
    
    static func aligned(comp: Computer, to: Pos) -> MoveSet {
        guard Util.isAligned(comp.pos, to) else {
            IO.log("Moveset.aligned, \(comp.pos) and \(to) is not aligned", type: .error)
            return MoveSet(comp: comp, moves: [])
        }
        let dirs = Util.dirsForPath(from: comp.pos, to: to)
        let moves = dirs.map { MoveV2(comp: comp, dir: $0 )}
        return MoveSet(comp: comp, moves: moves)
    }
    
    static func fromMixedMoves(moves: [MoveV2]) -> [MoveSet] {
        var moveSets = [MoveSet]()
        for move in moves {
            if let last = moveSets.last,
               last.comp == move.comp {
                moveSets[moveSets.count - 1].moves.append(move)
            }
            else {
                moveSets.append(MoveSet(comp: move.comp, moves: [move]))
            }
        }
        return moveSets
    }
}

struct MoveV2 {
    var comp: Computer
    var dir: Dir
    
    var nextPos: Pos {
        comp.pos + dir
    }
    
    func rev() -> MoveV2 {
        MoveV2(comp: comp, dir: dir.rev)
    }
}

struct Move: Command {
    var pos: Pos
    var dir: Dir
    
    var outValue: String {
        "\(pos.y) \(pos.x) \((pos + dir).y) \((pos + dir).x)"
    }
    
    func rev() -> Move {
        Move(pos: pos + dir, dir: dir.rev)
    }
}

struct Connect: Command, CommandV2 {
    var comp1: Computer
    var comp2: Computer
    
    init(comp1: Computer, comp2: Computer) {
        self.comp1 = comp1.id < comp2.id ? comp1 : comp2
        self.comp2 = comp1.id < comp2.id ? comp2 : comp1
    }

    var outValue: String {
        "\(comp1.pos.y) \(comp1.pos.x) \(comp2.pos.y) \(comp2.pos.x)"
    }
}

extension Connect: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(comp1)
        hasher.combine(comp2)
    }
}

extension Connect: Equatable {
    static func == (lhs: Connect, rhs: Connect) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}

struct Pos: Hashable {
    var x: Int
    var y: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension Pos {
    func isValid(boardSize: Int) -> Bool {
        x >= 0 && y >= 0 && x < boardSize && y < boardSize
    }
    
    func dist(to: Pos) -> Int {
        abs(to.x - x) + abs(to.y - y)
    }
}

extension Pos {
    static func ==(lhs: Pos, rhs: Pos) -> Bool {
        lhs.y == rhs.y && lhs.x == rhs.x
    }
    
    static func !=(lhs: Pos, rhs: Pos) -> Bool {
        !(lhs == rhs)
    }
    
    static func +=(lhs: inout Pos, rhs: Pos) {
        lhs.y += rhs.y
        lhs.x += rhs.x
    }
    
    static func +(lhs: Pos, rhs: Pos) -> Pos {
        Pos(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func +=(lhs: inout Pos, dir: Dir) {
        lhs.y += dir.pos.y
        lhs.x += dir.pos.x
    }
    
    static func +(lhs: Pos, dir: Dir) -> Pos {
        Pos(x: lhs.x + dir.pos.x, y: lhs.y + dir.pos.y)
    }
}
