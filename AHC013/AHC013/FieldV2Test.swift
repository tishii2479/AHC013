//
//  FieldV2Test.swift
//  AHC013Test
//
//  Created by Tatsuya Ishii on 2022/08/13.
//

import XCTest

class FieldV2Test: XCTestCase {

    func testPerformConnect() throws {
        let strs = [
            "00000",
            "00200",
            "00001",
            "10001",
            "00201"
        ]
        let field = parseField(strs: strs)
        let comps = field.computers
        
        XCTAssertTrue(field.canPerformConnect(comp1: comps[0], comp2: comps[4]))
        XCTAssertTrue(field.canPerformConnect(comp1: comps[2], comp2: comps[3]))
        XCTAssertTrue(field.canPerformConnect(comp1: comps[1], comp2: comps[3]))
        XCTAssertFalse(field.canPerformConnect(comp1: comps[1], comp2: comps[2]))
        XCTAssertFalse(field.canPerformConnect(comp1: comps[1], comp2: comps[5]))
        
        field.performConnect(comp1: comps[0], comp2: comps[4])
        
        XCTAssertFalse(field.canPerformConnect(comp1: comps[2], comp2: comps[3]))
        XCTAssertTrue(comps[0].connected.contains(comps[4]))
        XCTAssertTrue(comps[4].connected.contains(comps[0]))
        XCTAssertTrue(field.cell(pos: Pos(x: 2, y: 2)).isCabled)
        XCTAssertTrue(field.cell(pos: Pos(x: 2, y: 3)).isCabled)

        field.eraseConnect(comp1: comps[0], comp2: comps[4])
        XCTAssertFalse(comps[0].connected.contains(comps[4]))
        XCTAssertFalse(comps[4].connected.contains(comps[0]))
        XCTAssertFalse(field.cell(pos: Pos(x: 2, y: 2)).isCabled)
        XCTAssertFalse(field.cell(pos: Pos(x: 2, y: 3)).isCabled)
        XCTAssertTrue(field.canPerformConnect(comp1: comps[2], comp2: comps[3]))
    }
    
    func testPerformMoveSet() throws {
        let strs = [
            "00000",
            "00200",
            "00001",
            "10001",
            "00201"
        ]
        let field = parseField(strs: strs)
        let comps = field.computers
        let moveSet = MoveSet.aligned(comp: comps[2], to: Pos(x: 2, y: 3))
        XCTAssertTrue(field.canPerformMoveSet(moveSet: moveSet))
        
        field.performMoveSet(moveSet: moveSet)
        
        XCTAssertFalse(field.canPerformMoveSet(moveSet: moveSet))
        XCTAssertFalse(field.cell(pos: Pos(x: 0, y: 3)).isComputer)
        XCTAssertTrue(field.cell(pos: Pos(x: 2, y: 3)).isComputer)
        
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 2))))
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 3))))
        XCTAssertTrue(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[2], to: Pos(x: 2, y: 2))))

        field.reverseMoveSet(moveSet: moveSet)
        
        XCTAssertTrue(field.cell(pos: Pos(x: 0, y: 3)).isComputer)
        XCTAssertFalse(field.cell(pos: Pos(x: 2, y: 3)).isComputer)
        
        XCTAssertTrue(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 2))))
        XCTAssertTrue(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 3))))
    }
    
    func testCableAfterMove() throws {
        let strs = [
            "00000",
            "00200",
            "00001",
            "10001",
            "00201"
        ]
        let field = parseField(strs: strs)
        let comps = field.computers
        
        field.performConnect(comp1: comps[2], comp2: comps[3])
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 3))))
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[0], to: Pos(x: 2, y: 3))))
        
        XCTAssertTrue(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[2], to: Pos(x: 3, y: 3))))
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[2], to: Pos(x: 0, y: 0))))
        field.performMoveSet(moveSet: MoveSet.aligned(comp: comps[2], to: Pos(x: 3, y: 3)))
        
        XCTAssertTrue(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 3))))
        XCTAssertTrue(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[0], to: Pos(x: 2, y: 3))))
        XCTAssertTrue(field.canPerformConnect(comp1: comps[0], comp2: comps[4]))
        
        field.performMoveSet(moveSet: MoveSet.aligned(comp: comps[2], to: Pos(x: 0, y: 3)))
        
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[4], to: Pos(x: 2, y: 3))))
        XCTAssertFalse(field.canPerformMoveSet(moveSet: MoveSet.aligned(comp: comps[0], to: Pos(x: 2, y: 3))))
        XCTAssertFalse(field.canPerformConnect(comp1: comps[0], comp2: comps[4]))
    }
    
    private func parseField(strs: [String]) -> FieldV2 {
        let field = FieldV2(size: strs.count, computerTypes: 2, fieldInput: strs)
        return field
    }

}
