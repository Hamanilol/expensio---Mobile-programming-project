import UIKit

/// Uploads receipt photos to Cloudinary using an *unsigned* upload preset.
///
/// Unsigned uploads are a plain `multipart/form-data` POST — no SDK or secret
/// key required on the client, which is the right approach for a mobile app
/// (never embed your Cloudinary API *secret* in client code). The returned
/// `secure_url` is what gets stored on the Expense document in Firestore.
///
/// ⚠️ Setup requirement: `uploadPreset` below must be configured as
/// **Unsigned** in the Cloudinary console (Settings → Upload → Upload
/// presets). Cloudinary's default preset, "ml_default", is *signed* out of
/// the box — if uploads fail with a 401, go flip its Signing Mode to
/// Unsigned (or create a new preset dedicated to this app).
final class CloudinaryService {

    static let shared = CloudinaryService()
    private init() {}

    private let cloudName = "dcgs06flw"
    private let uploadPreset = "ml_default"

    private var uploadURL: URL {
        URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload")!
    }

    /// Uploads a UIImage and returns the hosted image's secure (https) URL.
    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(CloudinaryServiceError.invalidImage))
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(imageData: imageData, boundary: boundary)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard
                let data,
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                completion(.failure(CloudinaryServiceError.uploadFailed))
                return
            }

            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let secureURL = json["secure_url"] as? String
                else {
                    completion(.failure(CloudinaryServiceError.unexpectedResponse))
                    return
                }
                completion(.success(secureURL))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Multipart body construction

    private func multipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()

        func append(_ string: String) {
            body.append(string.data(using: .utf8)!)
        }

        // upload_preset field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n")
        append("\(uploadPreset)\r\n")

        // file field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        append("\r\n")

        append("--\(boundary)--\r\n")

        return body
    }
}

enum CloudinaryServiceError: LocalizedError {
    case invalidImage
    case uploadFailed
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "This image couldn't be processed. Try a different photo."
        case .uploadFailed:
            return "The receipt photo couldn't be uploaded. Check your connection and try again."
        case .unexpectedResponse:
            return "Received an unexpected response while uploading the photo."
        }
    }
}
