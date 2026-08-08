import SwiftUI

/// Semantic text styles Home needs, expressed as native Dynamic-Type-aware SwiftUI fonts
/// rather than porting Android's fixed sp sizes — this is the idiomatic iOS equivalent of
/// `MaterialTheme.typography.*`, not a pixel-for-pixel port.
public enum MTCTypography {
    public static let largeTitle = Font.largeTitle.weight(.bold)
    public static let title = Font.title2.weight(.bold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption.weight(.semibold)
}
