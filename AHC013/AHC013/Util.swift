class Util {
    static func getDir(from: Pos, to: Pos) -> [Dir] {
        let dy = to.y - from.y
        let dx = to.x - from.x
        
        var ret = [Dir]()
        
        if dy > 0 {
            ret.append(.down)
        }
        if dy < 0 {
            ret.append(.up)
        }
        if dx > 0 {
            ret.append(.right)
        }
        if dx < 0 {
            ret.append(.left)
        }
        
        return ret
    }
    
    static func toDir(from: Pos, to: Pos) -> Dir? {
        let dirs = getDir(from: from, to: to)
        guard dirs.count == 1 else {
            IO.log("Could not get dir from: \(from) to: \(to)", type: .warn)
            return nil
        }
        return dirs[0]
    }

    // TODO: Move to Direction.static
    static func fromDir(dir: Dir) -> Direction {
        switch dir {
        case .left:
            return .horizontal
        case .right:
            return .horizontal
        case .up:
            return .vertical
        case .down:
            return .vertical
        }
    }
    
    // TODO: Move to Direction.static
    static func direction(from: Pos, to: Pos) -> Direction? {
        guard let dir = toDir(from: from, to: to) else {
            IO.log("Could not get dir from: \(from) to: \(to)", type: .warn)
            return nil
        }
        return fromDir(dir: dir)
    }

    static func getBetweenPos(from: Pos, to: Pos, addEnd: Bool = false) -> [Pos] {
        guard from != to else { return [] }
        guard isAligned(from, to) else {
            IO.log("getBetweenPos: \(from) and \(to) is not aligned", type: .warn)
            return []
        }

        var ret = [Pos]()
    
        var cPos = from
        guard let dir = toDir(from: from, to: to) else {
            IO.log("Could not get dir for \(from), \(to)", type: .warn)
            return ret
        }
    
        while cPos + dir != to {
            ret.append(cPos + dir)
            cPos += dir
        }
        
        if addEnd {
            ret.append(to)
        }
    
        return ret
    }

    static func isAligned(_ a: Pos, _ b: Pos) -> Bool {
        let dy = abs(b.y - a.y)
        let dx = abs(b.x - a.x)
        
        return (dx > 0 && dy == 0) || (dx == 0 && dy > 0)
    }
    
    static func intersections(_ a: Pos, _ b: Pos) -> [Pos]? {
        if isAligned(a, b) {
            return nil
        }
        return [Pos(x: a.x, y: b.y), Pos(x: b.x, y: a.y)]
    }
    
    static func getMoves(from: Pos, to: Pos) -> [Move]? {
        guard from != to else {
            return []
        }
        guard let dir = toDir(from: from, to: to) else {
            IO.log("\(from), \(to) is not aligned", type: .warn)
            return nil
        }
        
        var cPos = from
        var ret = [Move]()
        
        while cPos != to {
            ret.append(Move(pos: cPos, dir: dir))
            cPos += dir
        }
        
        return ret
    }
    
    static func dirsForPath(from: Pos, to: Pos) -> [Dir] {
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
        return dirs
    }
    
    static func distF(a: Pos, b: Pos) -> Int {
        abs(b.x - a.x) + abs(b.y - a.y)
    }
}
