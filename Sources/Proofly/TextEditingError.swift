import Foundation

struct TextEditingError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
