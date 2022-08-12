import Foundation

let runLimitDate = Date().addingTimeInterval(2.7)

func isInTime() -> Bool {
    Date() < runLimitDate
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
    
    func hasConnectedComp(to dir: Dir) -> Bool {
        for comp in connected {
            if let compDir = Util.toDir(from: pos, to: comp.pos),
               dir == compDir {
                return true
            }
        }
        return false
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

struct Move: Command {
    var pos: Pos
    var dir: Dir
    
    var outValue: String {
        "\(pos.y) \(pos.x) \((pos + dir).y) \((pos + dir).x)"
    }
}

struct Connect: Command {
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
