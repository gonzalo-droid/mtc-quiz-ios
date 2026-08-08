import SwiftUI
import UIKit

public struct QuestionImageStrip: View {
    private let imageURLs: [URL]

    public init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(imageURLs, id: \.self) { url in
                    if let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
