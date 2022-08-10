//
//  FieldTest.swift
//  AHC013Test
//
//  Created by Tatsuya Ishii on 2022/08/10.
//

import XCTest

class FieldTest: XCTestCase {

    func testAdjacentComputer() throws {
        let fieldSize = 5
        let strs = [
            "00000",
            "00200",
            "00000",
            "20201",
            "00100"
        ]
        let field = Field(size: fieldSize)
        field.parseField(strs: strs)
        
        XCTAssertEqual(
            field.computers[1],
            field.getAdjacentComputer(pos: Pos(x: 2, y: 3), dir: .left)
        )
        XCTAssertEqual(
            field.computers[3],
            field.getAdjacentComputer(pos: Pos(x: 2, y: 3), dir: .right)
        )
        XCTAssertEqual(
            field.computers[0],
            field.getAdjacentComputer(pos: Pos(x: 2, y: 3), dir: .up)
        )
        XCTAssertEqual(
            field.computers[4],
            field.getAdjacentComputer(pos: Pos(x: 2, y: 3), dir: .down)
        )
        XCTAssert(
            field.getAdjacentComputer(pos: Pos(x: 2, y: 4), dir: .down)
            == nil
        )
    }
    
    func testCluster() throws {
        let fieldSize = 5
        let strs = [
            "00000",
            "00201",
            "03001",
            "20231",
            "00101"
        ]
        let field = Field(size: fieldSize)
        field.parseField(strs: strs)
            
        XCTAssertEqual(
            field.getCluster(ofComputerIdx: 1).count,
            5
        )
        XCTAssertEqual(
            field.getCluster(ofComputerIdx: 0).count,
            3
        )
        XCTAssertEqual(
            field.getCluster(ofComputerIdx: 2).count,
            1
        )
        
        XCTAssertTrue(
            field.isInSameCluster(compIdx1: 1, compIdx2: 3)
        )
        XCTAssertTrue(
            field.isInSameCluster(compIdx1: 0, compIdx2: 4)
        )
        XCTAssertFalse(
            field.isInSameCluster(compIdx1: 0, compIdx2: 1)
        )
        XCTAssertFalse(
            field.isInSameCluster(compIdx1: 2, compIdx2: 6)
        )
    }

}
