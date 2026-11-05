import AVFoundation
import CoreMedia
import Foundation
import Vision

/// Grabs a single low-resolution frame, runs on-device face detection, then tears the session down.
final class CameraPresenceDetector: NSObject {
    private let queue = DispatchQueue(label: "com.rodionlitvinoff.SightSave.camera", qos: .utility)
    private var permissionDenied = false

    var isPermissionDenied: Bool { permissionDenied }

    func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
            return granted
        case .denied, .restricted:
            permissionDenied = true
            return false
        @unknown default:
            permissionDenied = true
            return false
        }
    }

    /// Returns `true` if a face was detected. Camera hardware is released before returning.
    func detectFacePresent() async -> Bool {
        let authorized = await requestAccessIfNeeded()
        guard authorized else { return false }

        return await withCheckedContinuation { continuation in
            queue.async {
                let result = Self.captureAndDetect()
                continuation.resume(returning: result)
            }
        }
    }

    private static func captureAndDetect() -> Bool {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        defer {
            if session.isRunning {
                session.stopRunning()
            }
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                ?? AVCaptureDevice.default(for: .video)
        else {
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return false }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            guard session.canAddOutput(output) else { return false }
            session.addOutput(output)

            let gate = FrameGate()
            output.setSampleBufferDelegate(gate, queue: DispatchQueue(label: "com.rodionlitvinoff.SightSave.frame"))

            session.startRunning()
            let buffer = gate.waitForFrame(timeout: 2.0)
            session.stopRunning()

            guard let pixelBuffer = buffer else { return false }
            return detectFace(in: pixelBuffer)
        } catch {
            return false
        }
    }

    private static func detectFace(in pixelBuffer: CVPixelBuffer) -> Bool {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
            return !(request.results ?? []).isEmpty
        } catch {
            return false
        }
    }
}

private final class FrameGate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let lock = NSCondition()
    private var pixelBuffer: CVPixelBuffer?
    private var finished = false

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        finished = true
        lock.signal()
    }

    func waitForFrame(timeout: TimeInterval) -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while !finished {
            if !lock.wait(until: deadline) {
                break
            }
        }
        finished = true
        return pixelBuffer
    }
}
