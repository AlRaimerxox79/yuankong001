import AVFoundation
import UIKit

enum CameraCaptureService {
    static func capture(lens: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let position: AVCaptureDevice.Position = lens.lowercased() == "front" ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                completion(.failure(NSError(domain: "Camera", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "找不到摄像头"
                ])))
                return
            }

            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .photo

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    throw NSError(domain: "Camera", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "无法打开摄像头输入"
                    ])
                }
                session.addInput(input)

                let output = AVCapturePhotoOutput()
                guard session.canAddOutput(output) else {
                    throw NSError(domain: "Camera", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "无法创建拍照输出"
                    ])
                }
                session.addOutput(output)
                session.commitConfiguration()

                let semaphore = DispatchSemaphore(value: 0)
                var captureResult: Result<[String: Any], Error>?
                let delegate = PhotoDelegate { result in
                    captureResult = result
                    semaphore.signal()
                }
                session.startRunning()
                let settings = AVCapturePhotoSettings()
                output.capturePhoto(with: settings, delegate: delegate)
                if semaphore.wait(timeout: .now() + 10) == .timedOut {
                    captureResult = .failure(NSError(domain: "Camera", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "拍照超时"
                    ]))
                }
                session.stopRunning()
                completion(captureResult ?? .failure(NSError(domain: "Camera", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "拍照失败"
                ])))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let completion: (Result<[String: Any], Error>) -> Void
        private var finished = false

        init(completion: @escaping (Result<[String: Any], Error>) -> Void) {
            self.completion = completion
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard !finished else { return }
            finished = true
            if let error {
                completion(.failure(error))
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.85) else {
                completion(.failure(NSError(domain: "Camera", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "拍照数据无效"
                ])))
                return
            }
            completion(.success([
                "image": jpeg.base64EncodedString(),
                "width": Int(image.size.width),
                "height": Int(image.size.height),
                "lens": "camera"
            ]))
        }
    }
}
