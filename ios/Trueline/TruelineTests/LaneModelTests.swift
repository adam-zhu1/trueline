import CoreGraphics
import Testing
@testable import Trueline

func isClose(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

func isClose(_ a: CGPoint, _ b: CGPoint, _ tolerance: Double = 1e-6) -> Bool {
    isClose(Double(a.x), Double(b.x), tolerance) && isClose(Double(a.y), Double(b.y), tolerance)
}

@Suite("Lane model: boards and feet")
struct LaneModelBoardTests {
    @Test("board position ↔ across fraction round-trips for both hands",
          arguments: [LaneModel.Hand.right, .left])
    func boardRoundTrip(hand: LaneModel.Hand) {
        for position in stride(from: 0.0, through: 39.0, by: 0.25) {
            let t = LaneModel.tAcross(boardPosition: position, hand: hand)
            #expect(t >= 0 && t <= 1)
            #expect(isClose(LaneModel.boardPosition(tAcross: t, hand: hand), position))
        }
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            let position = LaneModel.boardPosition(tAcross: t, hand: hand)
            #expect(isClose(LaneModel.tAcross(boardPosition: position, hand: hand), t))
        }
    }

    @Test("boards count 39t from the right gutter; left hand mirrors")
    func boardConvention() {
        #expect(LaneModel.boardPosition(tAcross: 0) == 0)
        #expect(LaneModel.boardPosition(tAcross: 1) == 39)
        #expect(LaneModel.boardPosition(tAcross: 0.5) == 19.5)
        #expect(LaneModel.boardPosition(tAcross: 0, hand: .left) == 39)
        #expect(LaneModel.boardPosition(tAcross: 1, hand: .left) == 0)
    }

    @Test("board centers sit at (board - 0.5) / 39")
    func boardCenters() {
        #expect(isClose(LaneModel.tAcross(boardCenter: 1), 0.5 / 39))
        #expect(isClose(LaneModel.tAcross(boardCenter: 39), 38.5 / 39))
        // Board 20 is the center board: its center is exactly mid-lane.
        #expect(LaneModel.centerBoard == 20)
        #expect(isClose(LaneModel.tAcross(boardCenter: 20), 0.5))
        #expect(isClose(LaneModel.tAcross(boardCenter: 20, hand: .left), 0.5))
        // Left-handers count from the left gutter.
        #expect(isClose(LaneModel.tAcross(boardCenter: 1, hand: .left), 1 - 0.5 / 39))
        // A seam sits at the integer position, half a board from each center.
        #expect(isClose(LaneModel.tAcross(boardPosition: 5) - LaneModel.tAcross(boardCenter: 5), 0.5 / 39))
    }

    @Test("feet ↔ along fraction round-trips")
    func feetRoundTrip() {
        #expect(LaneModel.alongFraction(feet: 0) == 0)
        #expect(LaneModel.alongFraction(feet: 60) == 1)
        for feet in stride(from: 0.0, through: 62.6, by: 0.7) {
            #expect(isClose(LaneModel.feet(alongFraction: LaneModel.alongFraction(feet: feet)), feet))
        }
    }

    @Test("lane constants match USBC")
    func constants() {
        #expect(LaneModel.lengthFeet == 60)
        #expect(LaneModel.widthInches == 41.5)
        #expect(LaneModel.boardCount == 39)
        #expect(isClose(LaneModel.inchesPerBoard, 1.0641, 1e-4))
        #expect(isClose(LaneModel.boards(inches: 41.5), 39))
        #expect(LaneGeometry.laneLengthFeet == LaneModel.lengthFeet)
        #expect(LaneGeometry.laneWidthInches == LaneModel.widthInches)
        #expect(ShotResult.pocketBoards == LaneModel.pocketBoards)
    }
}

@Suite("Lane model: arrows and pins")
struct LaneModelMarkingTests {
    @Test("arrows sit on boards 5-35 every 5 boards")
    func arrowBoards() {
        #expect(LaneModel.arrowBoards == [5, 10, 15, 20, 25, 30, 35])
    }

    @Test("arrow V: 15 ft apex, 0.5 ft per arrow, outer arrows at 13.5 ft")
    func arrowDepths() {
        let expected: [Double: Double] = [5: 13.5, 10: 14, 15: 14.5, 20: 15, 25: 14.5, 30: 14, 35: 13.5]
        for (board, feet) in expected {
            #expect(isClose(LaneModel.arrowFeet(atBoard: board), feet))
        }
        #expect(isClose(LaneModel.arrowOuterFeet, 13.5))
        // Inside USBC's 12-16 ft band.
        for board in LaneModel.arrowBoards {
            let feet = LaneModel.arrowFeet(atBoard: board)
            #expect(feet >= 12 && feet <= 16)
            #expect(isClose(feet, LaneModel.arrowFeet(atBoard: 40 - board)))
        }
    }

    @Test("arrow V by board position is the board-number V shifted half a board")
    func arrowByPosition() {
        // A reading of 19.5 is the center of board 20: the apex.
        #expect(isClose(LaneModel.arrowFeet(atBoardPosition: 19.5), 15))
        #expect(isClose(LaneModel.arrowFeet(atBoardPosition: 4.5), 13.5))
        #expect(isClose(LaneModel.arrowFeet(atBoardPosition: 34.5), 13.5))
    }

    @Test("calibration taps use the same arrow model")
    func landmarkTargetsShareArrows() {
        let targets = LandmarkFit.targets
        #expect(targets.count == 6)
        #expect(isClose(targets[2].lane, CGPoint(x: LaneModel.tAcross(boardCenter: 35), y: 13.5)))
        #expect(isClose(targets[3].lane, CGPoint(x: 0.5, y: 15)))
        #expect(isClose(targets[4].lane, CGPoint(x: LaneModel.tAcross(boardCenter: 5), y: 13.5)))
        #expect(isClose(targets[5].lane, CGPoint(x: 0.5, y: 60)))
    }

    @Test("pin deck: ten spots on a 12 in equilateral triangle")
    func pins() {
        let pins = LaneModel.pins
        #expect(pins.map(\.number) == Array(1...10))
        let head = pins[0]
        #expect(head.board == 20 && head.feet == 60 && head.row == 0)

        // The values the overlay used to hard-code, to the hundredth.
        let rows = LaneModel.pinRows
        let expected: [(feet: Double, boards: [Double])] = [
            (60.00, [20]),
            (60.87, [14.36, 25.64]),
            (61.73, [8.72, 20, 31.28]),
            (62.60, [3.08, 14.36, 25.64, 36.92]),
        ]
        #expect(rows.count == expected.count)
        for (row, want) in zip(rows, expected) {
            #expect(isClose(row.feet, want.feet, 0.005))
            #expect(row.boards.count == want.boards.count)
            for (b, w) in zip(row.boards, want.boards) {
                #expect(isClose(b, w, 0.005))
            }
        }

        // Every neighbor pair is 12 in apart.
        func inches(_ a: LaneModel.Pin, _ b: LaneModel.Pin) -> Double {
            let dx = (a.board - b.board) * LaneModel.inchesPerBoard
            let dy = (a.feet - b.feet) * 12
            return (dx * dx + dy * dy).squareRoot()
        }
        let byNumber = Dictionary(uniqueKeysWithValues: pins.map { ($0.number, $0) })
        for (a, b) in [(1, 2), (1, 3), (2, 3), (2, 5), (3, 5), (4, 7), (4, 8), (6, 10), (9, 10)] {
            #expect(isClose(inches(byNumber[a]!, byNumber[b]!), 12, 1e-9))
        }
        // 3 pin is on the right-hander's side (lower boards).
        #expect(byNumber[3]!.board < 20 && byNumber[2]!.board > 20)
        #expect(LaneModel.pocketPins(hand: .right) == [1, 3])
        #expect(LaneModel.pocketPins(hand: .left) == [1, 2])
    }
}

@Suite("Lane geometry through a calibration")
struct LaneGeometryTests {
    /// A trapezoid that narrows toward the pins, like a down-lane view.
    static let corners = LaneCorners(
        farLeft: CGPoint(x: 0.42, y: 0.12),
        farRight: CGPoint(x: 0.58, y: 0.12),
        nearRight: CGPoint(x: 0.85, y: 0.95),
        nearLeft: CGPoint(x: 0.15, y: 0.95)
    )
    static let size = CGSize(width: 1080, height: 1920)

    @Test("image ↔ (board, feet) round-trips for both hands", arguments: [LaneModel.Hand.right, .left])
    func roundTrip(hand: LaneModel.Hand) throws {
        let geometry = try #require(LaneGeometry(corners: Self.corners, imageSize: Self.size, hand: hand))
        for board in [1.0, 5, 17.5, 20, 35, 39] {
            for feet in [0.0, 6, 15, 42, 59.5] {
                let t = LaneModel.tAcross(boardCenter: board, hand: hand)
                let p = geometry.imagePoint(tAcross: t, feet: feet)
                let back = geometry.boardFeet(atImage: p)
                #expect(isClose(back.board, board - 0.5, 1e-6))
                #expect(isClose(back.feet, feet, 1e-6))
            }
        }
    }

    @Test("center board's center lands on the image midline of the lane")
    func centerBoard() throws {
        let geometry = try #require(LaneGeometry(corners: Self.corners, imageSize: Self.size, hand: .right))
        // Symmetric trapezoid → mid-lane is x = 540 at every depth.
        for feet in [0.0, 15, 60] {
            let p = geometry.imagePoint(tAcross: LaneModel.tAcross(boardCenter: 20), feet: feet)
            #expect(isClose(Double(p.x), 540, 1e-6))
        }
    }
}
