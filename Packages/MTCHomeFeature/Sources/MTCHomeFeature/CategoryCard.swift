import SwiftUI
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

                VehicleIllustration(examId: category.examId)
                    .frame(width: 260, height: 155)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Clase A") {
    CategoryCard(
        category: MTCDomain.Category(
            id: "1",
            title: "CLASE A - CATEGORIA I",
            category: "A-I",
            classType: "CLASE A",
            description: "Es el más común y te permite manejar carros como sedanes, coupé, hatchback, convertibles, station wagon, SUV, Areneros, Pickup y furgones.",
            pdf: "CLASE_A_I.pdf",
            pathJson: "a1_questions.json"
        ),
        onSelect: {}
    )
    .padding(16)
}

#Preview("Clase B") {
    CategoryCard(
        category: MTCDomain.Category(
            id: "8",
            title: "CLASE B - CATEGORIA II-A",
            category: "B-IIa",
            classType: "CLASE B",
            description: "Bicimotos para transportar pasajeros o mercancías.",
            pdf: "CLASE_B_IIA.pdf",
            pathJson: "b2a_questions.json"
        ),
        onSelect: {}
    )
    .padding(16)
}

#Preview("Sin imagen (fallback)") {
    CategoryCard(
        category: MTCDomain.Category(
            id: "99",
            title: "Categoría de prueba",
            category: "A-I",
            classType: "CLASE A",
            description: "d",
            pdf: "p.pdf",
            pathJson: "no_existe_questions.json"
        ),
        onSelect: {}
    )
    .padding(16)
}
