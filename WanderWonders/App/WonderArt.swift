import SwiftUI
import UIKit

extension Image {
    static func wonder(_ assetKey: String) -> Image {
        guard let image = UIImage(named: "\(assetKey).png") else {
            preconditionFailure("Missing validated art asset: \(assetKey)")
        }
        return Image(uiImage: image)
    }
}
