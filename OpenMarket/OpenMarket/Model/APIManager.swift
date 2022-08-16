import Foundation
import UIKit
import Alamofire

typealias Parameters = [String: String]

class APIManager {
    // MARK: - Property
    static let shared = APIManager()
    let boundary = "Boundary-\(UUID().uuidString)"
    let urlSession: URLSessionProtocol
    let vendorSecret = VendorSecret()

    init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - API Method
    func checkAPIHealth() {
        guard let url = URLManager.healthChecker.url else { return }
        AF.request(url)
            .responseJSON {
            print($0)
        }
    }
    
    func checkProductDetail(id: Int, completion: @escaping (Result<ProductDetail, Error>) -> Void) {
        guard let url = URLManager.editOrCheckProductDetail(id: id).url else { return }
        AF.request(url)
            .validate()
            .responseData { response in
                switch response.result {
                case .success:
                    guard let responseData = response.value,
                          let decodedData = JSONParser.decodeData(of: responseData, type: ProductDetail.self) else {
                        return
                    }
                    completion(.success(decodedData))
                case .failure(let error):
                    completion(.failure(error))
                }
                
            }
    }
    
    func checkProductList(pageNumber: Int, itemsPerPage: Int, completion: @escaping (Result<ProductList, Error>) -> Void) {
        guard let url = URLManager.checkProductList(pageNumber: pageNumber, itemsPerPage: itemsPerPage).url else { return }
        AF.request(url)
            .validate()
            .responseData { response in
                switch response.result {
                case .success:
                    guard let responseData = response.value,
                          let decodedData = JSONParser.decodeData(of: responseData, type: ProductList.self) else {
                        return
                    }
                    completion(.success(decodedData))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    func uploadDataWithImage(information: NewProductInformation, images: [NewProductImage], completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = URLManager.addNewProduct.url,
              let informationData = JSONParser.encodeToDataString(with: information) else {
            return
        }
        let headers: Alamofire.HTTPHeaders = [
            "Content-Type": "multipart/form-data",
            "identifier": "819efbc3-71fc-11ec-abfa-dd40b1881f4c"
        ]
        let parameters = ["params": informationData]
        
        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: .utf8)!, withName: key)
            }
            for image in images {
                multipartFormData.append(image.data, withName: image.key, fileName: image.fileName, mimeType: "image/jpeg, image/jpg, image/png")
            }
            
        }, to: url, method: .post, headers: headers)
        .response { response in
            guard let statusCode = response.response?.statusCode else {
                return
            }
            completion(.success(statusCode))
        }
        
    }
    
    func editProduct(id: Int, product: NewProductInformation, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URLManager.editOrCheckProductDetail(id: id).url else { return }
        var request = URLRequest(url: url, method: .patch)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("819efbc3-71fc-11ec-abfa-dd40b1881f4c", forHTTPHeaderField: "identifier")
        request.httpBody = JSONParser.encodeToData(with: product)
        createDataTask(with: request, completion: completion)
    }
    
    func deleteProduct(id: Int, secret: String, completion: @escaping (Result<ProductDetail, Error>) -> Void) {
        guard let url = URLManager.deleteProduct(id: id, secret: secret).url else { return }
        var request = URLRequest(url: url, method: .delete)
        request.addValue("819efbc3-71fc-11ec-abfa-dd40b1881f4c", forHTTPHeaderField: "identifier")
        createDataTaskWithDecoding(with: request, completion: completion)
    }
    
    func checkProductSecret(id: Int, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URLManager.checkProductSecret(id: id).url else { return }
        var request = URLRequest(url: url, method: .post)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("819efbc3-71fc-11ec-abfa-dd40b1881f4c", forHTTPHeaderField: "identifier")
        request.httpBody = JSONParser.encodeToData(with: vendorSecret)
        createDataTask(with: request, completion: completion)
    }
}

extension APIManager {
    // MARK: - Create Request Body Method
    func createRequestBody(product: NewProductInformation, images: [NewProductImage]) -> Data {
        let parameters = createParams(with: product)
        let dataBody = createMultiPartFormData(with: parameters, images: images)
        return dataBody
    }
    
    func createParams(with modelData: NewProductInformation) -> Parameters? {
        guard let parameterBody = JSONParser.encodeToDataString(with: modelData) else { return nil }
        let params: Parameters = ["params": parameterBody]
        return params
    }
    
    func createMultiPartFormData(with params: Parameters?, images: [NewProductImage]?) -> Data {
        let lineBreak = "\r\n"
        var body = Data()
        
        if let parameters = params {
            for (key, value) in parameters {
                body.append("--\(boundary + lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)")
                body.append("\(value)\(lineBreak)")
            }
        }

        if let images = images {
            for image in images {
                body.append("--\(boundary + lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(image.key)\"; filename=\"\(image.fileName)\"\(lineBreak)")
                body.append("Content-Type: image/jpeg, image/jpg, image/png\(lineBreak + lineBreak)")
                body.append(image.data)
                body.append(lineBreak)
            }
        }
        
        body.append("--\(boundary)--\(lineBreak)")
        
        return body
    }
}

extension APIManager {
    // MARK: - Create DataTask Method
    func createDataTaskWithDecoding<T: Decodable>(with request: URLRequest, completion: @escaping (Result<T, Error>) -> Void) {
        let task = urlSession.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 300 {
                completion(.failure(URLSessionError.responseFailed(code: httpResponse.statusCode)))
                return
            }
            
            if let error = error {
                completion(.failure(URLSessionError.requestFailed(description: error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLSessionError.invaildData))
                return
            }
            guard let decodedData = JSONParser.decodeData(of: data, type: T.self) else {
                completion(.failure(JSONError.dataDecodeFailed))
                return
            }
            completion(.success(decodedData))
        }
        task.resume()
    }
    
    func createDataTask(with request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = urlSession.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode >= 300 {
                completion(.failure(URLSessionError.responseFailed(code: httpResponse.statusCode)))
                return
            }
            
            if let error = error {
                completion(.failure(URLSessionError.requestFailed(description: error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLSessionError.invaildData))
                return
            }

            completion(.success(data))
        }
        task.resume()
    } 
}

extension APIManager {
    struct VendorSecret: Codable {
        var secret: String = "EE5ud*rBT9Nu38_d"
    }
}
