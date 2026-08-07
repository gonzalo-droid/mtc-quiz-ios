import SwiftUI
import UIKit
import MTCDomain
import MTCDesignSystem

public struct CategoryCard: View {
    private let category: MTCDomain.Category
    private let onSelect: () -> Void

    public init(category: MTCDomain.Category, onSelect: @escaping () -> Void) {
        self.category = category
        self.onSelect = onSelect
    }

    public var body: some View {
        let palette = MTCColor.categoryPalette(for: category.category)

        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                palette.container

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.classType)
                        .font(MTCTypography.caption)
                        .foregroundStyle(palette.content)
                    Text(category.category)
                        .font(MTCTypography.title)
                        .foregroundStyle(palette.content)
                }
                .padding(16)

                vehicleImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var vehicleImage: Image {
        if
            let url = Bundle.module.url(forResource: "\(category.examId)_card", withExtension: "png"),
            let uiImage = UIImage(contentsOfFile: url.path)
        {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "car.fill")
    }
}
