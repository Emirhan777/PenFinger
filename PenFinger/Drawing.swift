import SwiftUI

enum InkColor: String, CaseIterable, Identifiable {
    case black = "Black"
    case white = "White"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"

    var id: Self { self }

    var uiColor: UIColor {
        switch self {
        case .black: .black
        case .white: .white
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

struct DrawingStroke {
    let color: InkColor
    var points: [CGPoint]
}

struct Drawing {
    private(set) var color: InkColor = .black
    private(set) var strokes: [DrawingStroke] = []
    private var pointCount = 0
    private var needsNewStroke = true

    var isStrokeActive: Bool { !needsNewStroke }

    mutating func selectColor(_ color: InkColor) {
        guard self.color != color else { return }
        self.color = color
        needsNewStroke = true
    }

    mutating func append(_ point: CGPoint) {
        if needsNewStroke || strokes.isEmpty {
            strokes.append(DrawingStroke(color: color, points: [point]))
            needsNewStroke = false
        } else {
            strokes[strokes.count - 1].points.append(point)
        }
        pointCount += 1

        // Preserve the existing limit across all colors.
        if pointCount > 3000 {
            strokes[0].points.removeFirst()
            if strokes[0].points.isEmpty { strokes.removeFirst() }
            pointCount -= 1
        }
    }

    mutating func clear() {
        strokes.removeAll()
        pointCount = 0
        needsNewStroke = true
    }

    mutating func endStroke() {
        needsNewStroke = true
    }
}
