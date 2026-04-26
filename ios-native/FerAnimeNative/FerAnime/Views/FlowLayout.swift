import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var rows: [CGSize] = [CGSize(width: 0, height: 0)]

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + size.width + spacing > width {
                rows.append(size)
            } else {
                rows[rows.count - 1].width += size.width + spacing
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            }
        }

        return CGSize(width: width, height: rows.reduce(0) { $0 + $1.height + spacing })
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

