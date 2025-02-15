import UIKit

class CameraHandler: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = CameraHandler()

    private var completion: ((UIImage?) -> Void)?

    func presentCamera(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.allowsEditing = false

            if let topController = UIApplication.shared.windows.first?.rootViewController {
                topController.present(imagePicker, animated: true, completion: nil)
            }
        } else {
            print("Camera not available")
            completion(nil)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[.originalImage] as? UIImage
        completion?(image)
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        completion?(nil)
        picker.dismiss(animated: true, completion: nil)
    }
}
