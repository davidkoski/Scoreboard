//
//  Camera.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import Foundation
import AsyncAlgorithms
import AVFoundation

#if os(iOS)
import UIKit
#endif

enum CameraError : Error {
    case notAuthorized
    case videoDeviceNotAvailable
    case unableToAddInput
    case unableToAddOutput
}

@Observable
public class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let session = AVCaptureSession()

    public var frames: AsyncStream<CMSampleBuffer>!
    private var framesContinuation: AsyncStream<CMSampleBuffer>.Continuation!
    
    private let queue = DispatchQueue(label: "CameraController")
    
    enum State {
        case initial
        case idle
        case running
    }
    private var state = State.idle
    
    private var orientationTask: Task<Void, Never>?

    public override init() {
        super.init()
        self.frames = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c in
            self.framesContinuation = c
        }
        self.orientationTask = Task {
            await observeOrientationChanges()
        }
    }
    
    deinit {
        switch state {
        case .initial, .idle:
            break
        case .running:
            session.stopRunning()
        }
    }
    
    private func observeOrientationChanges() async {
        #if os(iOS)
        for await update in await NotificationCenter.default.notifications(
            named: UIDevice.orientationDidChangeNotification)
        {
            if let device = update.object as? UIDevice {
                let orientation = await device.orientation
                queue.sync {
                    setOrientation(orientation)
                }
            }
        }
        #endif
    }

    #if os(iOS)
    private func setOrientation(_ orientation: UIDeviceOrientation) {
        let angle: Double?
        switch orientation {
        case .unknown, .faceDown:
            angle = nil
        case .portrait, .faceUp:
            angle = 90
        case .portraitUpsideDown:
            angle = 270
        case .landscapeLeft:
            angle = 0
        case .landscapeRight:
            angle = 180
        @unknown default:
            angle = nil
        }

        if let angle {
            for output in session.outputs {
                output.connection(with: .video)?.videoRotationAngle = angle
            }
        }
    }
    #endif

    @MainActor
    public func start() async throws {
        switch state {
        case .initial:
            try await authorize()
            state = .idle
            try await startCamera()
            state = .running
        case .idle:
            try await startCamera()
            state = .running
        case .running:
            break
        }
    }
    
    @MainActor
    public func stop() async throws {
        switch state {
        case .initial:
            break
        case .idle:
            break
        case .running:
            try await stopCamera()
            state = .idle
        }
    }
    
    private func authorize() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
                
            case .authorized:
                // already allowed
                continuation.resume()
                
            case .notDetermined:
                // they haven't decided yet
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if !granted {
                        continuation.resume(throwing: CameraError.notAuthorized)
                    } else {
                        continuation.resume()
                    }
                }
            case .denied, .restricted:
                continuation.resume(throwing: CameraError.notAuthorized)
                
            @unknown default:
                continuation.resume(throwing: CameraError.notAuthorized)
            }
        }
    }
    
    private func startCamera() async throws {
        #if os(macOS)
        let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.continuityCamera, .external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .front)
        #else
        let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back)
        #endif
        
        guard let videoDevice =
                videoDeviceDiscoverySession.devices.first(where: { $0.isContinuityCamera }) ??
                videoDeviceDiscoverySession.devices.first else {
            throw CameraError.videoDeviceNotAvailable
        }
        
        session.beginConfiguration()
        
        try videoDevice.lockForConfiguration()
        defer {
            videoDevice.unlockForConfiguration()
        }
        
        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        
        session.sessionPreset = .hd1280x720

        guard session.canAddInput(videoInput) else {
            throw CameraError.unableToAddInput
        }

        session.addInput(videoInput)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        guard session.canAddOutput(videoDataOutput) else {
            throw CameraError.unableToAddOutput
        }
        
        videoDataOutput.setSampleBufferDelegate(self, queue: queue)
        
        session.addOutput(videoDataOutput)
        
        session.commitConfiguration()
        
        session.startRunning()
    }
    
    private func stopCamera() async throws {
        session.stopRunning()
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if sampleBuffer.isValid && sampleBuffer.imageBuffer != nil {
            framesContinuation.yield(sampleBuffer)
        }
    }
}
