import SwiftUI
import UIKit

/// The system share sheet, presentable from code. `ShareLink` can only be triggered by the user
/// tapping it, and the PDF screen has to run the interstitial gate *before* the sheet appears.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
