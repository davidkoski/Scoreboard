//
//  ContentView.swift
//  OCRTest
//
//  Created by David Koski on 6/2/24.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct ContentView: View {
    
    @State var files = [URL]()
    @State var input: CIImage?
    @State var context = CIContext()
    
    @State var detected: String?
    
    @State var noir = false
    @State var otsu = false
    @State var max = false
    @State var median = 0
    @State var maximum = 0
    @State var posterize = 0
    @State var sharpen = 0

    var body: some View {
        VStack {
            HStack {
                ForEach(files, id: \.self) { file in
                    Button(action: { select(file) }) {
                        Text("\(file.lastPathComponent.prefix(8))")
                    }
                }
            }
            
            HStack {
                if input != nil {
                    VStack {
                        Toggle("Noir", isOn: $noir)
                        Toggle("OTSU", isOn: $otsu)
                        Toggle("Max", isOn: $max)
                        HStack {
                            Stepper("Median", value: $median)
                            Text("\(median)")
                        }
                        HStack {
                            Stepper("Dilate", value: $maximum)
                            Text("\(maximum)")
                        }
                        HStack {
                            Stepper("Posterize", value: $posterize)
                            Text("\(posterize)")
                        }
                        HStack {
                            Stepper("Sharpen", value: $sharpen)
                            Text("\(sharpen)")
                        }
                    }
                }
                VStack {
                    if let detected {
                        Text(detected)
                    }
                    if let image {
                        Image(image, scale: 0.5, label: Text(""))
                            .resizable()
                            .scaledToFit()
                    }
                    if let processed {
                        Image(processed, scale: 0.5, label: Text(""))
                            .resizable()
                            .scaledToFit()
                    }
                }
            }
            
        }
        .task {
            files = findImages()
        }
    }
    
    var image: CGImage? {
        if let input {
            context.createCGImage(input, from: input.extent)
        } else {
            nil
        }
    }
    
    var processed: CGImage? {
        if let input {
            var image = input
            
            // Good:
            // otsu + 1 dilate
            // max + 1 dilate
            
            if noir {
                let filter = CIFilter.photoEffectNoir()
                filter.inputImage = image
                image = filter.outputImage!
            }
            
            if otsu {
                let filter = CIFilter.colorThresholdOtsu()
                filter.inputImage = image
                image = filter.outputImage!
            }
            if max {
                let filter = CIFilter.maximumComponent()
                filter.inputImage = image
                image = filter.outputImage!
            }

            if median > 0 {
                for _ in 0 ..< median {
                    let filter = CIFilter.median()
                    filter.inputImage = image
                    image = filter.outputImage!
                }
            }

            if posterize > 0 {
                let filter = CIFilter.colorPosterize()
                filter.inputImage = image
                filter.levels = Float(posterize)
                image = filter.outputImage!
            }

            if maximum > 0 {
                let filter = CIFilter.morphologyMaximum()
                filter.inputImage = image
                filter.radius = Float(maximum)
                image = filter.outputImage!
            }
            if maximum < 0 {
                let filter = CIFilter.morphologyMinimum()
                filter.inputImage = image
                filter.radius = Float(-maximum)
                image = filter.outputImage!
            }
            if sharpen > 0 {
                let filter = CIFilter.sharpenLuminance()
                filter.inputImage = image
                filter.radius = Float(sharpen)
                filter.sharpness = 1
                image = filter.outputImage!
            }

            let processed = context.createCGImage(image, from: image.extent)
            
            Task {
                self.detected = await detect(processed!)
            }
            
            
            return processed
        } else {
            return nil
        }
    }
    
    private func detect(_ input: CGImage) async -> String? {
        let requestHandler = VNImageRequestHandler(cgImage: input)
        
        return await withCheckedContinuation { continuation in
            
            let request = VNRecognizeTextRequest() { response, error in
                guard let response = response as? VNRecognizeTextRequest else {
                    continuation.resume(returning: nil)
                    return
                }
                for item in response.results ?? [] {
                    if item.confidence > 0.8 {
                        continuation.resume(returning: item.topCandidates(1)[0].string)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
            
            try? requestHandler.perform([request])
        }
    }
    
    private func select(_ url: URL) {
        input = CIImage(contentsOf: url)
    }

    private func findImages() -> [URL] {
        let bundle = Bundle.main
        if let resources = bundle.resourceURL {
            return try! FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil, options: [])
                .filter {
                    switch $0.pathExtension.lowercased() {
                    case "jpg", "jpeg", "png", "heic":
                        return true
                    default:
                        return false
                    }
                }
        }
        return []
    }
}
