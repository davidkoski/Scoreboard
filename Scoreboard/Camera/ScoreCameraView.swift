//
//  ScoreCamera.swift
//  Scoreboard
//
//  Created by David Koski on 5/27/24.
//

import AVFoundation
import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI
import VideoToolbox
import Vision

/// Internal view to display a CVImageBuffer
#if os(iOS)
    private struct _ImageView: UIViewRepresentable {

        let image: Any
        var gravity = CALayerContentsGravity.resizeAspect

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.layer.contentsGravity = gravity
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            uiView.layer.contents = image
        }

    }
#else
    private struct _ImageView: NSViewRepresentable {

        let image: Any
        var gravity = CALayerContentsGravity.resizeAspect

        func makeNSView(context: Context) -> some NSView {
            let view = NSView()
            view.wantsLayer = true
            view.layer?.contentsGravity = gravity
            return view
        }

        func updateNSView(_ nsView: NSViewType, context: Context) {
            if let layer = nsView.layer {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.contents = image
                CATransaction.commit()
            }
        }
    }
#endif

private struct ImageView: View {

    let image: Any
    let zoom: Bool

    var body: some View {
        _ImageView(image: image)
            .scaleEffect(
                zoom ? CGSize(width: 2, height: 2) : CGSize(width: 1, height: 1)
            )
            .padding(4)
    }
}

/// Display a live camera view
public struct ScoreCameraView: View {

    static private let conversionQueue = DispatchQueue(label: "CameraView.convert")

    public var gravity: CALayerContentsGravity = .resizeAspect

    @Binding var score: Int

    @State private var image: Any?
    @State private var recognizedImage: Any?
    @State private var processedImage: Any?
    @State private var scores = CountedSet<Int>()

    @State var showProcessed = false

    @State var ciContext = CIContext()

    enum SCState {
        case running
        case pause
        case zoomLive
        case zoomRecognized

        func tapMain() -> SCState {
            switch self {
            case .running: .pause
            case .pause: .running
            case .zoomLive: .running
            case .zoomRecognized: .zoomRecognized
            }
        }

        func tapRecognized() -> SCState {
            switch self {
            case .running: .zoomRecognized
            case .pause: .zoomRecognized
            case .zoomLive: .running
            case .zoomRecognized: .pause
            }
        }

        func tapRecognizedDisabled() -> Bool {
            switch self {
            case .running: true
            case .pause: false
            case .zoomLive: true
            case .zoomRecognized: false
            }
        }
    }

    @State var state = SCState.running

    public var body: some View {
        HStack {
            if let image {
                switch state {
                case .running, .pause, .zoomLive:
                    ImageView(image: image, zoom: state == .zoomLive)
                        .overlay(alignment: .bottom) {
                            HStack {
                                if state != .zoomLive {
                                    Button(action: { state = state.tapMain() }) {
                                        Image(
                                            systemName: state == .pause
                                                ? "play.circle.fill" : "pause.circle.fill"
                                        )
                                        .resizable()
                                        .foregroundStyle(.black, .white)
                                        .opacity(0.5)
                                        .frame(width: 60, height: 60)
                                        .padding()
                                    }
                                    Button(action: { state = .zoomLive }) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .resizable()
                                            .foregroundStyle(.white, .black)
                                            .opacity(0.5)
                                            .frame(width: 60, height: 60)
                                            .padding()
                                    }
                                    .disabled(state == .zoomLive)
                                }
                            }
                        }
                        .onTapGesture {
                            state = state.tapMain()
                        }
                case .zoomRecognized:
                    EmptyView()
                }
            }
            if let recognizedImage, let processedImage {
                switch state {
                case .zoomLive:
                    EmptyView()
                case .running, .pause, .zoomRecognized:
                    let image = showProcessed ? processedImage : recognizedImage
                    ImageView(image: image, zoom: state == .zoomRecognized)
                        .overlay(alignment: .bottom) {
                            HStack {
                                if state != .zoomRecognized {
                                    Button(action: { state = state.tapRecognized() }) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .resizable()
                                            .foregroundStyle(.white, .black)
                                            .opacity(0.5)
                                            .frame(width: 60, height: 60)
                                            .padding()
                                    }
                                }
                                Button(action: { showProcessed.toggle() }) {
                                    Image(systemName: "rectangle.2.swap")
                                        .resizable()
                                        .foregroundStyle(.black, .white)
                                        .opacity(0.5)
                                        .frame(width: 60, height: 60)
                                        .padding()
                                }
                            }
                        }
                        .onTapGesture {
                            state = state.tapRecognized()
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            let cameraController = CameraController()
            try? await cameraController.start()

            for await sampleBuffer in cameraController.frames {
                switch state {
                case .running:
                    break
                case .pause, .zoomLive, .zoomRecognized:
                    continue
                }

                if let imageBuffer = sampleBuffer.imageBuffer {

                    if let image = liveView(imageBuffer) {
                        let processedImages = process(image)

                        let tuple =
                            await processedImages
                            .async
                            .compactMap {
                                let image = await ciContext.createCGImage($0, from: $0.extent)!
                                if let (score, confidence) = await detect(image) {
                                    return (image, score, confidence)
                                } else {
                                    return nil
                                }
                            }
                            .max {
                                $0.2 > $1.2
                            }

                        if let (processedImage, bestScore, confidence) = tuple {
                            scores.add(bestScore)
                            if let best = scores.mostFrequent() {
                                self.score = best
                                self.processedImage = processedImage
                                self.recognizedImage = self.image
                            }
                            if scores.count > 10 {
                                scores.removeAll()
                            }
                        }
                    }
                }
            }
        }
    }

    private func liveView(_ imageBuffer: CVPixelBuffer) -> CIImage? {
        if CVPixelBufferGetIOSurface(imageBuffer) != nil {
            self.image = imageBuffer
            return CIImage(cvImageBuffer: imageBuffer)
        } else {
            var cgImage: CGImage? = nil
            VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgImage)
            self.image = cgImage
            if let cgImage {
                return CIImage(cgImage: cgImage)
            } else {
                return nil
            }
        }
    }

    private func process(_ image: CIImage) -> [CIImage] {
        var results = [CIImage]()

        // otsu
        do {
            var image = image

            do {
                let filter = CIFilter.colorThresholdOtsu()
                filter.inputImage = image
                image = filter.outputImage!
            }

            results.append(image)
        }

        // otsu + dilate 1
        do {
            var image = image

            do {
                let filter = CIFilter.colorThresholdOtsu()
                filter.inputImage = image
                image = filter.outputImage!
            }
            do {
                let filter = CIFilter.morphologyMaximum()
                filter.inputImage = image
                filter.radius = 1
                image = filter.outputImage!
            }

            results.append(image)
        }

        // max + dilate 1
        do {
            var image = image

            do {
                let filter = CIFilter.maximumComponent()
                filter.inputImage = image
                image = filter.outputImage!
            }
            do {
                let filter = CIFilter.morphologyMaximum()
                filter.inputImage = image
                filter.radius = 1
                image = filter.outputImage!
            }

            results.append(image)
        }

        // noir + dilate 3
        do {
            var image = image

            do {
                let filter = CIFilter.photoEffectNoir()
                filter.inputImage = image
                image = filter.outputImage!
            }
            do {
                let filter = CIFilter.morphologyMaximum()
                filter.inputImage = image
                filter.radius = 3
                image = filter.outputImage!
            }

            results.append(image)
        }

        return results
    }

    private func process(score: String) -> Int? {
        let score =
            score
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingPrefix(while: { $0 == "0" })

        return Int(score)
    }

    private func detect(_ image: CGImage) async -> (Int, VNConfidence)? {
        let requestHandler = VNImageRequestHandler(cgImage: image)

        return await withCheckedContinuation { continuation in

            let request = VNRecognizeTextRequest { response, error in
                guard let response = response as? VNRecognizeTextRequest else {
                    continuation.resume(returning: (0, 0))
                    return
                }
                for item in response.results ?? [] {
                    let confidence = item.confidence
                    if confidence > 0.8 {
                        if let score = process(score: item.topCandidates(1)[0].string) {
                            continuation.resume(returning: (score, confidence))
                            return
                        }
                    }
                }
                continuation.resume(returning: nil)
            }

            try? requestHandler.perform([request])
        }
    }
}
