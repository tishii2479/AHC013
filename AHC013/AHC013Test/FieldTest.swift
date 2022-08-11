//
//  FieldTest.swift
//  AHC013Test
//
//  Created by Tatsuya Ishii on 2022/08/10.
//

import XCTest

class FieldTest: XCTestCase {

    func testAdjacentComputer() throws {
        let size = 5
        let strs = [
            "00000",
            "00200",
            "00000",
            "20201",
            "00100"
        ]
        let field = Field(size: size)
        field.parseField(strs: strs)
        
        XCTAssertEqual(
            field.computers[1],
            field.getNearestComputer(pos: Pos(x: 2, y: 3), dir: .left)
        )
        XCTAssertEqual(
            field.computers[3],
            field.getNearestComputer(pos: Pos(x: 2, y: 3), dir: .right)
        )
        XCTAssertEqual(
            field.computers[0],
            field.getNearestComputer(pos: Pos(x: 2, y: 3), dir: .up)
        )
        XCTAssertEqual(
            field.computers[4],
            field.getNearestComputer(pos: Pos(x: 2, y: 3), dir: .down)
        )
        XCTAssert(
            field.getNearestComputer(pos: Pos(x: 2, y: 4), dir: .down)
            == nil
        )
    }
    
    func testCluster() throws {
        let size = 5
        let strs = [
            "00000",
            "00201",
            "03001",
            "20231",
            "00101"
        ]
        let field = Field(size: size)
        field.parseField(strs: strs)
            
        XCTAssertEqual(
            field.getCluster(ofComputer: field.computers[1]).count,
            5
        )
        XCTAssertEqual(
            field.getCluster(ofComputer: field.computers[0]).count,
            3
        )
        XCTAssertEqual(
            field.getCluster(ofComputer: field.computers[2]).count,
            1
        )
        
        XCTAssertTrue(
            field.isInSameCluster(
                comp1: field.computers[1],
                comp2: field.computers[3]
            )
        )
        XCTAssertTrue(
            field.isInSameCluster(
                comp1: field.computers[0],
                comp2: field.computers[4]
            )
        )
        XCTAssertFalse(
            field.isInSameCluster(
                comp1: field.computers[0],
                comp2: field.computers[1]
            )
        )
        XCTAssertFalse(
            field.isInSameCluster(
                comp1: field.computers[2],
                comp2: field.computers[6]
            )
        )
    }
    
    func testCalcScore() throws {
        let size = 5
        let strs = [
            "00000",
            "00201",
            "03001",
            "20231",
            "00101"
        ]
        let field = Field(size: size)
        field.parseField(strs: strs)
        
        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[6], to: Pos(x: 3, y: 2)),
            1
        )
        
        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[9], to: Pos(x: 3, y: 4)),
            -6
        )
        
        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[0], to: Pos(x: 2, y: 0)),
            0
        )

        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[5], to: Pos(x: 2, y: 2)),
            -2
        )
        
        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[3], to: Pos(x: 3, y: 2)),
            -4
        )
    }
    
    func testCalcScore2() throws {
        let size = 5
        let strs = [
            "10101",
            "00000",
            "10101",
            "00000",
            "10101"
        ]
        let field = Field(size: size)
        field.parseField(strs: strs)
        
        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[4], to: Pos(x: 1, y: 1)),
            -8
        )
        
        XCTAssertEqual(
            field.calcMoveDiff(comp: field.computers[4], to: Pos(x: 1, y: 2)),
            0
        )
    }

}
