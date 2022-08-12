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
