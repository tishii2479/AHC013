struct Queue<T> {
    private var values: [T] = [T]()
    private var ptr: Int = 0
    
    var count: Int {
        values.count - ptr
    }
    
    mutating func push(_ v: T) {
        values.append(v)
    }
    
    mutating func pop() -> T? {
        guard ptr < values.count else {
            return nil
        }
        
        let ret = values[ptr]
        ptr += 1
        return ret
    }
}

class UnionFind {
    private let n: Int
    private var par: [Int]
    
    init(n: Int) {
        self.n = n
        self.par = [Int](repeating: -1, count: n)
    }

    @discardableResult
    func merge(_ a: Int, _ b: Int) -> Bool {
        var a = root(of: a), b = root(of: b)
        guard a != b else { return false }
        if par[a] > par[b] {
            swap(&a, &b)
        }
        par[a] += par[b]
        par[b] = a
        return true
    }
    
    func same(_ a: Int, _ b: Int) -> Bool {
        root(of: a) == root(of: b)
    }
    
    func root(of a: Int) -> Int {
        if par[a] < 0 {
            return a
        }
        par[a] = root(of: par[a])
        return par[a]
    }
    
    func size(of a: Int) -> Int {
        -par[root(of: a)]
    }
}
