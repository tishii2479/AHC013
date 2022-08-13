# 解法

1. 1つ目のクラスタを作る
    - MSTを解くように
        - BFS（ビームサーチ）でやったらどうなるか
    - 他のCを動かすときは、いい感じに動かす
        - いい感じとは、邪魔にならない and 同じ種類とは接続しやすい
    - コストが小さくなるようにビームサーチ
        - 現状のクラスターの大きさと、移動コストを計算して比較したい
        - 移動コストをとにかく減らしたい
2. 2つ目以降のクラスタを作る
    - BFSで近くにクラスタを作る
        - これもビームサーチでコスト最小化
    - ケーブルを接続するときに、既にあるクラスタが邪魔なら接続し直せるなら付け替える
    - 今のクラスタでもそうする

# TODO:

## 接続

```swift
// field.swift
func canConnect(comp1:,comp2:) -> Bool {
    // guard 既に接続されていないか
    // 間にケーブルがないか
    // alignしているか
}
func performConnect(comp1:,comp2:) {
    // ケーブルを引く
    // コンピュータに登録する
}
func eraseConnect(comp1:,comp2:) {
    // guard comp1とcomp2が接続されている
    // ケーブルを消す
    // コンピュータの登録を消す
}
```

```swift
// solver.swift
```

```swift
extension Computer {
    func isConnected(to:Computer) -> Bool {
        return connected.contains(to)
    }
}
```

## 移動

```swift
struct MoveSet {
    var start: Pos
    var to: Pos
    var moves: [Move]

    func rev() {
        swap(start, to)
        moves = moves.reverse().map { Move.rev() }
    }
}
```

```swift
// field.swift

func canApplyMoveSet(moveSet:) {
    // guard moveSet.to にコンピュータ、違う種類のケーブルがない
    // guard 経路にコンピュータがない
    // guard ケーブルが切れない（移動方向と異なる向きのケーブルがない）
}

func performMoveSet(moveSet:) {
    // 間にいた場合、ケーブルをつなぎ直す
    // comp1 = comp.comp1, comp2 = comp.comp2
    // eraseConnect(comp, comp1)
    // eraseConnect(comp, comp2)
    // performConnect(comp1, comp2)
    for move in moveSet {
        performMove(move)
    }
    // 間に移動する場合、ケーブルをつなぎ直す
    // comp1 = moveSet.to.cable.comp1, comp2 = moveSet.to.cable.comp2
    // comp = moveSet.to.comp
    // eraseConnect(comp1, comp2)
    // performConnect(comp, comp1)
    // performConnect(comp, comp2)
}

func reverseMoveSet(moveSet:) {
    performMoveSet(moveSet.rev())
}

private func performMove(move:) {
    // ケーブルを伸ばす必要があれば伸ばす
    // 移動したマスにケーブルがあって、それが自分につながっているものなら消す
    // コンピュータの位置を動かす
}
```

```swift
// solver.swift
```

## ビームサーチ

```swift
// searcher.swift
func search() {
    let eval = { (moves: Int, cableLength: Int) -> Int in
        return moves
    }

    // score, state
    var dp[clusterSize][beam_width] := (Int, State)
    for clusterSize in 0 ..< maxClusterSize {
        // score, beamIndex, commands
        var evalNextCommands = [(Int, Int, [Command])]()
        for b in 0 ..< beamWidth {
            let currentScore, state = dp[clusterSize][b]
            for nextCommands in solver.commands(state) {
                let scoreDiff = newCommands.count
                let score = currentScore
                evalNextCommands.append((score, b, nextCommands))
            }
        }
        evalNextCommands.sort({ $0.0 > $1.0 })
        for i in 0 ..< beamWidth {
            let score, b, commands = evalNextCommands[i]
            let currentScore, state = dp[clusterSize][b]
            state.snapshot()
            state.performCommands(commands)
            dp[clusterSize + 1][i] = (score, state.copy())
            state.rollback()
        }
    }
}

// bfsSolver.swift
func commands(state: State, trial: Int) {
    guard let state = state as? BfsState else {
        fatalError()
    }
    // 現在のクラスターを拡大する
    // 伸ばすコンピュータを選択する
    var commands: [[Command]]

    state.snapshot()
    for _ in 0 ..< trial {
        guard let comp = state.await.random() else {
            // もう伸ばせない
            return
        }
        for newComp in nearComp(for: comp).random() {
            if state.cluster.contains(newComp) {
                continue
            }
            guard let moves = movesToConnect(state, comp, newComp) else {
                continue
            }
            commands.append(moves + [Connect(newComp, comp)])
            state.rollback()
        }
    }
    return commands
}

func mstCommands(state:) {
    // TODO: Implement
}

class BfsState: State {
    let cluster: Cluster
    let await: Set<Computer>

    override func performConnectIfPossible(comp1:, comp2:) {
        if super.performConnectIfPossible(comp1, comp2) {
        }
        else {
        }
    }
}

class MstState: State {
}

class State {
    private var snapShotPoint: Int
    private(set) let field: Field

    private var commands: [Command]

    private var moveSets: [MoveSet]
    private var connects: Set<Connect>

    func performCommands(commands: [Command]) {
        for command in commands {
            if let moveset = command as? MoveSet {
                performMoveSetIfPossible(moveSet)
            }
            else if let connect = command as? Connect {
                performConnectIfPossible(connect)
            }
            else {
                fatalError()
            }
        }
    }

    func performConnectIfPossible(comp1:, comp2:) -> Bool {
        guard field.canConnect(comp1, comp2) else {
            return false
        }
        let connect = Connect(comp1, comp2)
        connects.insert(connect)
        field.performConnect(comp1, comp2)
        return true
    }

    func eraseConnect(connect) {
        connects.remove(connect)
        field.eraseConnect(connect.comp1, connect.comp2)
    }

    func performMoveSetIfPossible(moveSet:) -> Bool {
        guard field.canApplyMoveSet(moveSet) else {
            return false
        }
        moveSets.append(moveSet)
        field.performMoveSet(moveSet)
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
            else if let connect = command {
                eraseConnect(connect)
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
        field.reverseMoveSet(moveSet)
    }
}
```
