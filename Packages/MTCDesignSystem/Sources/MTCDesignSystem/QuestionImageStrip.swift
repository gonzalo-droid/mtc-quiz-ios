import SwiftUI
import UIKit

public struct QuestionImageStrip: View {
    private let imageURLs: [URL]
    @State private var loadedImages: [URL: UIImage] = [:]

    public init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(imageURLs, id: \.self) { url in
                    if let uiImage = loadedImages[url] {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        // Keyed on imageURLs so this only re-runs when the question's images actually
        // change, not on every body re-evaluation (e.g. QuizView's per-second timer tick) —
        // the decode happens once per question instead of once per second.
        .task(id: imageURLs) {
            var decoded: [URL: UIImage] = [:]
            for url in imageURLs {
                if let uiImage = UIImage(contentsOfFile: url.path) {
                    decoded[url] = uiImage
                }
            }
            loadedImages = decoded
        }
    }
}
