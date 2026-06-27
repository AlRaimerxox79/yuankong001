import AVFoundation
import CoreImage
import Foundation
import ReplayKit
import UIKit

final class ScreenCaptureService {
    static let shared = ScreenCaptureService()

    private let recorder = RPScreenRecorder.shared()
    private var isCapturing = false
    private var frameIntervalMs: Int = 500
    private var lastFrameSent: TimeInterval = 0
    private var onFrame: ((ScreenFramePayload) -> Void)?

    func start(intervalMs: Int, onFrame: @escaping (ScreenFramePayload) -> Void) throws {
        guard recorder.isAvailable else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "当前设备不支持屏幕录制"
            ])
        }

        stop()
        frameIntervalMs = max(200, min(intervalMs, 2000))
        self.onFrame = onFrame
        lastFrameSent = 0

        try recorder.startCapture(handler: { [weak self] sampleBuffer, bufferType, error in
            guard let self = self, bufferType == .video, error == nil else { return }
            let now = Date().timeIntervalSince1970
            if now - self.lastFrameSent < Double(self.frameIntervalMs) / 1000.0 {
                return
            }
            self.lastFrameSent = now
            if let frame = self.makeFrame(from: sampleBuffer) {
                self.onFrame?(frame)
            }
        })

        isCapturing = true
    }

    func stop() {
        if isCapturing {
            recorder.stopCapture { _ in }
            isCapturing = false
        }
        onFrame = nil
    }

    private func makeFrame(from sampleBuffer: CMSampleBuffer) -> ScreenFramePayload? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpeg = uiImage.jpegData(compressionQuality: 0.55) else { return nil }

        return ScreenFramePayload(
            image: jpeg.base64EncodedString(),
            width: width,
            height: height,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }
}
