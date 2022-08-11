class Computer {
    var id: Int
    init(id: Int) {
        self.id = id
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

struct Connect: Hashable {
    var comp1: Computer
    var comp2: Computer

    init(comp1: Computer, comp2: Computer) {
        self.comp1 = comp1.id < comp2.id ? comp1 : comp2
        self.comp2 = comp1.id < comp2.id ? comp2 : comp1
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(comp1)
        hasher.combine(comp2)
    }
}

extension Connect: Equatable {
    static func == (lhs: Connect, rhs: Connect) -> Bool {
        let a = min(lhs.comp1.id, lhs.comp2.id) == min(rhs.comp1.id, rhs.comp2.id)
        let b = max(lhs.comp1.id, lhs.comp2.id) == max(rhs.comp1.id, rhs.comp2.id)
        return a && b
    }
}

struct Cable {
    var comp: Computer
}

var s = Set<Computer>()
s.insert(Computer(id: 1))
s.insert(Computer(id: 2))
s.insert(Computer(id: 2))

print(s.count)

s.remove(Computer(id: 1))

print(s.count)

var st = Set<Connect>()
st.insert(Connect(comp1: Computer(id: 1), comp2: Computer(id: 2)))
st.insert(Connect(comp1: Computer(id: 2), comp2: Computer(id: 2)))
st.insert(Connect(comp1: Computer(id: 1), comp2: Computer(id: 1)))
st.insert(Connect(comp1: Computer(id: 2), comp2: Computer(id: 1)))

print(Connect(comp1: Computer(id: 1), comp2: Computer(id: 2)).hashValue)
print(Connect(comp1: Computer(id: 2), comp2: Computer(id: 1)).hashValue)

print(st.count)

st.remove(Connect(comp1: Computer(id: 2), comp2: Computer(id: 1)))

print(st.count)

var cable = Cable(comp: Computer(id: 1))
let a = cable.comp

print(a.id)

cable.comp = Computer(id: 2)

print(a.id)
