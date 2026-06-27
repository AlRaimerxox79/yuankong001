import Foundation
import Photos
import UIKit

enum GalleryService {
    static func listPhotos(limit: Int, offset: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    fetchList(limit: limit, offset: offset, completion: completion)
                } else {
                    completion(.failure(NSError(domain: "Gallery", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "相册权限被拒绝"
                    ])))
                }
            }
            return
        }
        guard status == .authorized || status == .limited else {
            completion(.failure(NSError(domain: "Gallery", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "相册权限被拒绝"
            ])))
            return
        }
        fetchList(limit: limit, offset: offset, completion: completion)
    }

    private static func fetchList(limit: Int, offset: Int, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            let total = assets.count
            let max = min(limit > 0 ? limit : 80, 200)
            var photos: [[String: Any]] = []
            var skipped = 0

            assets.enumerateObjects { asset, _, stop in
                if skipped < offset {
                    skipped += 1
                    return
                }
                if photos.count >= max {
                    stop.pointee = true
                    return
                }
                photos.append([
                    "id": asset.localIdentifier,
                    "displayName": photoFilename(for: asset),
                    "date": Int64((asset.creationDate?.timeIntervalSince1970 ?? 0) * 1000),
                    "size": 0,
                    "width": asset.pixelWidth,
                    "height": asset.pixelHeight
                ])
            }

            completion(.success([
                "photos": photos,
                "total": total,
                "offset": offset,
                "limit": max
            ]))
        }
    }

    static func loadImage(
        id: String,
        maxWidth: Int,
        thumbnail: Bool,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else {
            completion(.failure(NSError(domain: "Gallery", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "照片不存在"
            ])))
            return
        }

        let targetSize: CGSize
        if thumbnail {
            let w = CGFloat(maxWidth > 0 ? maxWidth : 320)
            targetSize = CGSize(width: w, height: w)
        } else if maxWidth > 0 {
            let scale = CGFloat(maxWidth) / CGFloat(max(asset.pixelWidth, 1))
            targetSize = CGSize(width: CGFloat(maxWidth), height: CGFloat(asset.pixelHeight) * scale)
        } else {
            targetSize = PHImageManagerMaximumSize
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image = image, let data = image.jpegData(compressionQuality: 0.85) else {
                completion(.failure(NSError(domain: "Gallery", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "无法解码图片"
                ])))
                return
            }
            let filename = photoFilename(for: asset)
            completion(.success([
                "id": id,
                "filename": filename,
                "image": data.base64EncodedString(),
                "width": Int(image.size.width),
                "height": Int(image.size.height),
                "thumbnail": thumbnail
            ]))
        }
    }

    static func loadThumbs(ids: [String], maxWidth: Int, completion: @escaping ([String: Any]) -> Void) {
        var thumbs: [String: String] = [:]
        let group = DispatchGroup()
        let width = maxWidth > 0 ? maxWidth : 280

        for id in ids {
            group.enter()
            loadImage(id: id, maxWidth: width, thumbnail: true) { result in
                if case .success(let payload) = result, let image = payload["image"] as? String {
                    thumbs[id] = image
                }
                group.leave()
            }
        }
        group.notify(queue: .global()) {
            completion(["thumbs": thumbs])
        }
    }

    private static func photoFilename(for asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename ?? "photo.jpg"
    }
}
