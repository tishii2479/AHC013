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

    static func getBetweenPos(from: Pos, to: Pos, addEnd: Bool = false) -> [Pos] {
        guard isAligned(from, to) else {
            IO.log("\(from) and \(to) is not aligned", type: .warn)
            return []
        }

        var ret = [Pos]()
    
        var cPos = from
        guard let dir = getDir(from: from, to: to).first else {
            IO.log("Could not get dir", type: .warn)
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
}
