import SwiftUI
import TensorFlowLite
import UIKit

// Extensión para inicializar un Array desde Data
extension Array {
    /// Inicializa un array desde `Data` en formato binario.
    init?(unsafeData: Data) {
        self = unsafeData.withUnsafeBytes {
            Array($0.bindMemory(to: Element.self))
        }
    }
}

// Extensión para convertir una UIImage a escala de grises
extension UIImage {
/// Convierte la imagen a escala de grises, invierte los colores y aplica binarización.
    func toInvertedBinarizedGrayscale(threshold: UInt8 = 128) -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = Int(self.size.width)
        let height = Int(self.size.height)

        // Crear un contexto en escala de grises
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let cgImage = self.cgImage else { return nil }

        // Dibujar la imagen original en escala de grises
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let grayscaleData = context.data else { return nil }

        // Aplicar binarización manualmente
        let pixelBuffer = grayscaleData.bindMemory(to: UInt8.self, capacity: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let pixelValue = pixelBuffer[pixelIndex]
                pixelBuffer[pixelIndex] = pixelValue > threshold ? 0 : 255  // Invertir binarización
            }
        }

        // Crear una nueva imagen con los datos binarizados
        if let outputCGImage = context.makeImage() {
            return UIImage(cgImage: outputCGImage)
        }
        return nil
    }
/// Corrige la orientación de la imagen basándose en los metadatos EXIF.
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage
    }
    
/// Convierte la imagen a escala de grises y devuelve los datos como `Float32`.
    func toGrayscaleData() -> Data? {
        let size = CGSize(width: 28, height: 28)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        guard let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage else {
            return nil
        }
        UIGraphicsEndImageContext()
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var data = Data(count: width * height)
        
        data.withUnsafeMutableBytes { pointer in
            if let context = CGContext(data: pointer.baseAddress,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.none.rawValue) {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        
        // Normaliza los valores de 0-255 a 0.0-1.0 y convierte a Float32
        return data.map { Float32($0) / 255.0 }.withUnsafeBytes { Data($0) }
    }
    
/// Convierte la imagen a escala de grises e invierte los colores.
    func toInvertedGrayscale() -> UIImage? {
        // Convertir a escala de grises
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let cgImage = self.cgImage,
              let context = CGContext(data: nil,
                                      width: cgImage.width,
                                      height: cgImage.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: cgImage.width,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        // Obtener la imagen en escala de grises
        guard let grayscaleImage = context.makeImage() else { return nil }

        // Invertir los colores
        let ciImage = CIImage(cgImage: grayscaleImage)
        let invertedFilter = CIFilter(name: "CIColorInvert")
        invertedFilter?.setValue(ciImage, forKey: kCIInputImageKey)

        if let outputImage = invertedFilter?.outputImage {
            let context = CIContext()
            if let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: outputCGImage)
            }
        }
        return nil
    }
    
/// Redimensiona la imagen al tamaño especificado.
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
/// Convierte la imagen a formato RGBA y la devuelve como `Data`.
    func toRGBAData() -> Data? {
        let size = CGSize(width: 28, height: 28)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = resizedImage.cgImage else {
            return nil
        }
        UIGraphicsEndImageContext()
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var data = Data(count: height * bytesPerRow)
        
        data.withUnsafeMutableBytes { pointer in
            if let context = CGContext(data: pointer.baseAddress,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: bytesPerRow,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        return data
    }
}

struct ContentView: View {
    @State private var capturedImage: UIImage?              // Imagen original capturada
    @State private var preprocessedImage: UIImage?          // Imagen preprocesada (invertida y redimensionada)
    @State private var prediction: String = "No prediction yet"
    @State private var confidence: String = ""

    private let modelFileName = "mnist_model"
    private var interpreter: Interpreter?

    init() {
        self.interpreter = try? Interpreter(modelPath: Bundle.main.path(forResource: modelFileName, ofType: "tflite")!)
    }

    var body: some View {
        VStack {
            // Imagen original capturada
            if let image = capturedImage {
                Text("Original Image")
                    .font(.headline)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else {
                Text("Capture a digit to classify")
                    .font(.headline)
            }

            // Imagen preprocesada
            if let processedImage = preprocessedImage {
                Text("Preprocessed Image")
                    .font(.headline)
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }

            // Predicción y confianza
            Text(prediction)
                .font(.title)
                .padding(.top, 20)
            
            Text(confidence)
                .font(.subheadline)

            Button(action: captureImage) {
                Text("Capture Image")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private func captureImage() {
        CameraHandler.shared.presentCamera { image in
            self.capturedImage = image
            if let image = image {
                self.predict(image: image)
            }
        }
    }

    private func predict(image: UIImage) {
        // Corregir la orientación de la imagen
        let correctedImage = image.fixedOrientation()
        
        // Preprocesamiento: convertir a binarizada, invertida y redimensionada
        guard let binarizedImage = correctedImage.toInvertedBinarizedGrayscale(threshold: 128),
              let resizedImage = binarizedImage.resize(to: CGSize(width: 28, height: 28)),
              let grayscaleData = resizedImage.toGrayscaleData() else {
            self.prediction = "Error: Image preprocessing failed"
            return
        }
        
        // Guardar la imagen preprocesada para mostrarla en la vista
        self.preprocessedImage = resizedImage

        guard let interpreter = interpreter else {
            self.prediction = "Error: Model not loaded"
            return
        }

        do {
            // Configuración e invocación del modelo
            try interpreter.allocateTensors()
            try interpreter.copy(grayscaleData, toInputAt: 0) // Copia datos en escala de grises
            try interpreter.invoke()
            let outputTensor = try interpreter.output(at: 0)

            // Procesar los resultados
            let results = [Float](unsafeData: outputTensor.data) ?? []

            if let maxIndex = results.indices.max(by: { results[$0] < results[$1] }) {
                let confidenceValue = results[maxIndex] * 100

                // Verificar la confianza de la predicción
                if confidenceValue < 20.0 {
                    self.prediction = "The photo taken is probably not a handwritten digit."
                    self.confidence = ""
                } else {
                    self.prediction = "Predicted digit: \(maxIndex)"
                    self.confidence = String(format: "Confidence: %.2f%%", confidenceValue)
                }
            } else {
                self.prediction = "No prediction available"
                self.confidence = ""
            }
        } catch {
            self.prediction = "Prediction failed: \(error)"
            self.confidence = ""
        }
    }
}
