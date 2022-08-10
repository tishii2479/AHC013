import Foundation

let runLimitDate = Date().addingTimeInterval(2.7)

class Computer {
    var id: Int
    var type: Int
    var pos: Pos
    
    init(id: Int, type: Int, pos: Pos) {
        self.id = id
        self.type = type
        self.pos = pos
    }
}

extension Computer: Equatable {
    static func == (lhs: Computer, rhs: Computer) -> Bool {
        lhs.id == rhs.id
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
