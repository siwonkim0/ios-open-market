import Foundation

struct NewProductImage {
    let key: String
    let fileName: String
    let data: Data
    
    init(key: String = "images", fileName: String = "test.jpg", data: Data) {
        self.key = key
        self.fileName = fileName
        self.data = data
    }
}
