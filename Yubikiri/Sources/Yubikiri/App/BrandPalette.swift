import SwiftUI

/// icon.svgの配色（生成り色の背景・赤い糸・小指の焦茶）に合わせたブランドカラー。
enum BrandPalette {
    static let thread = Color(red: 0.784, green: 0.259, blue: 0.176)      // #C8422D
    static let ink = Color(red: 0.227, green: 0.180, blue: 0.153)         // #3A2E27
    static let creamTop = Color(red: 0.984, green: 0.965, blue: 0.933)    // #FBF6EE
    static let creamBottom = Color(red: 0.941, green: 0.902, blue: 0.827) // #F0E6D3

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [creamTop, creamBottom], startPoint: .top, endPoint: .bottom)
    }
}
