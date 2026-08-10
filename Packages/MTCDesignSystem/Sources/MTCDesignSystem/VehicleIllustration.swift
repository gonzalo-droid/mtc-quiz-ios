import SwiftUI
import UIKit

/// Ilustración de vehículo de una categoría, cargada desde el bundle de este paquete.
/// Compartida entre Home (`CategoryCard`) y Detail — antes vivía duplicada solo en Home.
public struct VehicleIllustration: View {
    private let examId: String

    public init(examId: String) {
        self.examId = examId
    }

    public var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }

    private var image: Image {
        if
            let url = Bundle.module.url(forResource: "\(examId)_card", withExtension: "png"),
            let uiImage = UIImage(contentsOfFile: url.path)
        {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "car.fill")
    }
}
