func getDir(from: Pos, to: Pos) -> Dir? {
    let dy = to.y - from.y
    let dx = to.x - from.x
    
    let y = dy == 0 ? 0 : (dy > 0 ? 1 : -1)
    let x = dx == 0 ? 0 : (dx > 0 ? 1 : -1)
    
    let pos = Pos(x: x, y: y)
    
    for dir in Dir.all {
        if dir.pos == pos {
            return dir
        }
    }
    
    IO.log("from:\(from) and to:\(to) is not aligned", type: .warn)
    
    return nil
}

func betweenPos(p1: Pos, p2: Pos) -> [Pos] {
    var ret = [Pos]()
    
    var cPos = p1
    guard let dir = getDir(from: p1, to: p2) else {
        IO.log("Could not get dir", type: .warn)
        return ret
    }
    
    while cPos + dir != p2 {
        ret.append(cPos + dir)
        cPos += dir
    }
    
    return ret
}
