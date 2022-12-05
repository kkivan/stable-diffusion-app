//
//  ContentView.swift
//  stable-diffusion-sample
//
//  Created by Ivan Kvyatkovskiy on 05/12/2022.
//

import SwiftUI

// input state
// timer for generation
// copy to pasteboard

struct ContentView: View {
    @ObservedObject var model = Model()
    @State var input: String = "a photo of an astronaut riding a horse on mars"

    @State var currentDate = Date.now
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            switch model.image {
                case .generated(let image, let input, let time):
                    HStack {
                        Image(image,
                              scale: 1,
                              label: Text("LABEL"))
                        Text("\(input)").font(.italic(.body)())
                    }

                    Text("Generated in \(time) seconds")
                    Button("Again") {
                        model.reset()
                    }
                case .generating(let at, let input):
                    VStack(spacing: 10) {
                        Text("\(input)").font(.italic(.body)())
                        ProgressView()
                        let distance = max(Int(at.distance(to: currentDate)), 0)
                        Text("\(distance)").monospacedDigit()
                    }.onReceive(timer) { now in
                        currentDate = now
                    }

                case .input:
                    VStack {
                        TextField("enter text",
                                  text: $input,
                                  axis: .vertical)
                        .lineLimit(nil)
                        .textFieldStyle(.roundedBorder)
                        Button("Generate") {
                            model.generate(input)
                        }
                    }
                case .error(let error):
                    Text(error.localizedDescription)
                    Button("Again") {
                        model.reset()
                    }
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

import StableDiffusion

enum ModelState {
    case generated(image: CGImage, input: String, time: Int)
    case generating(startedAt: Date, input: String)
    case input
    case error(Error)
}

class Model: ObservableObject {
    @Published var image: ModelState = .input
    let q = DispatchQueue.global(qos: .userInitiated)

    func generate(_ input: String) {
        let startedAt = Date()
        image = .generating(startedAt: startedAt, input: input)
        let resourceURL = Bundle.main.resourceURL!
        q.async {
            do {
                let pipeline = try StableDiffusionPipeline(resourcesAt: resourceURL)
                let seed = Int.random(in: 5...100)
                let images = try pipeline.generateImages(prompt: input, seed: seed).compactMap { $0 } 
                DispatchQueue.main.async {
                    self.image = .generated(image: images.first!, input: input, time: Int(startedAt.distance(to: Date())))
                }
            } catch {
                self.image = .error(error)
            }
        }
    }

    func reset() {
        image = .input
    }
}
