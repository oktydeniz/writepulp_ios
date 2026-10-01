//
//  ImageUpload.swift
//  writepulp
//

import UIKit

/// Folder the backend stores an uploaded image in.
enum ImageUploadType: String {
    case avatar = "AVATAR"
    case cover = "COVER"
    case icon = "ICON"
    case group = "GROUP"
    case section = "SECTION"
    case message = "MESSAGE"
}

enum ImageUploadAPI {
    /// `data` is `{ "filePath": "..." }`.
    static func upload(jpeg: Data, type: ImageUploadType) -> Endpoint<[String: String]> {
        var form = MultipartForm()
        form.addFile("file", fileName: "\(UUID().uuidString).jpg", mimeType: "image/jpeg", data: jpeg)
        form.addField("type", value: type.rawValue)
        return Endpoint(path: "files/upload", method: .post, multipart: form)
    }
}

extension UIImage {
    /// Scales down to `maxDimension` on the long side and encodes as JPEG
    /// (the backend accepts jpeg/png/webp/gif only).
    func compressedJPEG(maxDimension: CGFloat = 1080, quality: CGFloat = 0.8) -> Data? {
        let longSide = max(size.width, size.height)
        let scale = min(1, maxDimension / longSide)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
