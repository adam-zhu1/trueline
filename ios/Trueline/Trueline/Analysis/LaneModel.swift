import Foundation

/// The physical lane and the one coordinate convention every surface shares:
/// analysis (LaneGeometry, ShotAnalyzer), calibration (LandmarkFit, the
/// overlay), and the drawn lanes (results canvas, home hero, brand art).
///
/// Across: `tAcross` runs 0...1 from the RIGHT gutter edge to the LEFT gutter
/// edge as seen from the approach. Boards count from the outside gutter edge
/// of the bowling hand (the right gutter for right-handers), 39 boards wide.
///
/// - A *board position* is continuous: 39·t from the outside edge, so 0 is
///   the gutter edge, 19.5 the center line, 39 the far edge. Measured
///   readings (path samples, arrows, breakpoint, entry) are positions; this is
///   the harness's x * 39 convention (fixed Sep 7, 7018d43).
/// - A *board number* names a physical board, 1...39. Board k spans positions
///   k-1 to k, so its center sits at position k - 0.5, i.e.
///   t = (k - 0.5) / 39. Lane markings (arrows, dots, pin spots) sit on board
///   centers and must convert through `tAcross(boardCenter:)`. Board 20 is
///   the center board: its center is exactly t = 0.5.
/// - A seam (the line between boards k and k+1) sits at position k.
///
/// Down-lane: feet 0 = foul line, 60 = head pin spot.
enum LaneModel {
    enum Hand: Sendable { case right, left }

    // MARK: - Lane constants (USBC)

    static let lengthFeet = 60.0
    static let widthInches = 41.5
    static let boardCount = 39.0
    static let inchesPerBoard = widthInches / boardCount
    /// The center board (number), the head pin's board.
    static let centerBoard = 20.0
    /// Approach-side guide dots, used for the near-lane pixel scale.
    static let dotRowFeet = 6.0
    /// Where Specto reads entry board: just ahead of the head pin.
    static let entryBoardFeet = 59.5

    // MARK: - Across the lane

    /// Continuous board position from the hand's outside gutter edge.
    static func boardPosition(tAcross t: Double, hand: Hand = .right) -> Double {
        switch hand {
        case .right: return t * boardCount
        case .left: return (1.0 - t) * boardCount
        }
    }

    /// Inverse of `boardPosition(tAcross:hand:)`.
    static func tAcross(boardPosition position: Double, hand: Hand = .right) -> Double {
        let t = position / boardCount
        switch hand {
        case .right: return t
        case .left: return 1.0 - t
        }
    }

    /// Continuous position of a numbered board's center (board k → k - 0.5).
    static func boardPosition(ofBoardCenter board: Double) -> Double {
        board - 0.5
    }

    /// Across fraction of a numbered board's center: (board - 0.5) / 39 for a
    /// right-hander. Use this for anything painted on the lane.
    static func tAcross(boardCenter board: Double, hand: Hand = .right) -> Double {
        tAcross(boardPosition: boardPosition(ofBoardCenter: board), hand: hand)
    }

    /// Lateral distance in boards for a distance in inches.
    static func boards(inches: Double) -> Double {
        inches / inchesPerBoard
    }

    // MARK: - Down the lane

    /// 0 at the foul line, 1 at the head pin.
    static func alongFraction(feet: Double) -> Double {
        feet / lengthFeet
    }

    static func feet(alongFraction u: Double) -> Double {
        u * lengthFeet
    }

    // MARK: - Arrows

    /// The seven targeting arrows sit on the centers of these boards.
    static let arrowBoards: [Double] = [5, 10, 15, 20, 25, 30, 35]

    /// Arrow V, one model for every surface. USBC only bounds the arrows to
    /// 12-16 ft past the foul line; the exact V is house-specific. The v1.1
    /// calibration references (experiments/calibration_v11, fit_reference.py
    /// and build_reference.py on the alley clips) fitted the apex at
    /// 14.5-15.2 ft with a 0.5 ft step per arrow, so the nominal V is the
    /// center arrow at 15 ft and each arrow 6 in nearer the foul line per 5
    /// boards out, putting the outer arrows (5 and 35) at 13.5 ft. This is
    /// the model the 6-tap calibration targets and the overlay were validated
    /// with; the overlay refine step absorbs the per-house difference.
    static let arrowApexFeet = 15.0
    /// Depth change per arrow (5 boards) away from the center arrow.
    static let arrowStepFeet = 0.5
    static let arrowSpacingBoards = 5.0

    /// Arrow-V depth at a numbered board (the V continues linearly past the
    /// outer arrows so the arrow-crossing search has a line to cross).
    static func arrowFeet(atBoard board: Double) -> Double {
        arrowApexFeet - abs(board - centerBoard) / arrowSpacingBoards * arrowStepFeet
    }

    /// Arrow-V depth at a continuous board position (a measured reading).
    static func arrowFeet(atBoardPosition position: Double) -> Double {
        arrowFeet(atBoard: position + 0.5)
    }

    /// The outer arrows' depth (boards 5 and 35): 13.5 ft.
    static var arrowOuterFeet: Double {
        arrowFeet(atBoard: arrowBoards[0])
    }

    // MARK: - Pin deck

    struct Pin: Equatable, Sendable {
        /// Standard pin number, 1 = head pin, 7 = left corner from behind a
        /// right-hander, 10 = right corner.
        let number: Int
        /// Row from the head pin, 0...3.
        let row: Int
        /// Board number of the pin spot's center (right-hand convention).
        let board: Double
        /// Feet from the foul line.
        let feet: Double
    }

    /// Pins sit 12 in apart on an equilateral triangle, so rows are
    /// 12·sin 60° = 10.39 in deep.
    static let pinSpacingInches = 12.0
    static let pinRowDepthFeet = pinSpacingInches * (3.0.squareRoot() / 2) / 12

    /// All ten pin spots, ordered by pin number.
    static let pins: [Pin] = {
        // Lateral offset in half pin spacings (6 in), + toward the left gutter.
        let layout: [(number: Int, row: Int, halfSpacings: Double)] = [
            (1, 0, 0),
            (2, 1, 1), (3, 1, -1),
            (4, 2, 2), (5, 2, 0), (6, 2, -2),
            (7, 3, 3), (8, 3, 1), (9, 3, -1), (10, 3, -3),
        ]
        let halfSpacingBoards = boards(inches: pinSpacingInches / 2)
        return layout.map { p in
            Pin(
                number: p.number,
                row: p.row,
                board: centerBoard + p.halfSpacings * halfSpacingBoards,
                feet: lengthFeet + Double(p.row) * pinRowDepthFeet
            )
        }
    }()

    /// Pin spots grouped by row, front to back, boards ascending.
    static var pinRows: [(feet: Double, boards: [Double])] {
        (0...3).map { row in
            let inRow = pins.filter { $0.row == row }
            return (inRow[0].feet, inRow.map(\.board).sorted())
        }
    }

    /// The pocket pins for a hand: 1-3 for right-handers, 1-2 for left.
    static func pocketPins(hand: Hand = .right) -> Set<Int> {
        hand == .right ? [1, 3] : [1, 2]
    }

    /// The strike pocket as an entry-board range from the bowler's side
    /// (hand-normalized, so the same range for both hands).
    static let pocketBoards: ClosedRange<Double> = 17...18
}
