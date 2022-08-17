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
              let informationData = JSONParser.encodeToData(with: information) else {
            return
        }
        let headers: Alamofire.HTTPHeaders = [
            "Content-Type": "multipart/form-data",
            "identifier": "819efbc3-71fc-11ec-abfa-dd40b1881f4c"
        ]
        let parameters = ["params": informationData]
        
        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value, withName: key)
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

        AF.request(request)
            .responseData { response in
                guard let data = response.value else {
                    return
                }
                completion(.success(data))
            }
    }
    
    func deleteProduct(id: Int, secret: String, completion: @escaping (Result<ProductDetail, Error>) -> Void) {
        guard let url = URLManager.deleteProduct(id: id, secret: secret).url else { return }
        var request = URLRequest(url: url, method: .delete)
        request.addValue("819efbc3-71fc-11ec-abfa-dd40b1881f4c", forHTTPHeaderField: "identifier")
        AF.request(request)
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
    
    func checkProductSecret(id: Int, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URLManager.checkProductSecret(id: id).url else { return }
        var request = URLRequest(url: url, method: .post)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("819efbc3-71fc-11ec-abfa-dd40b1881f4c", forHTTPHeaderField: "identifier")
        request.httpBody = JSONParser.encodeToData(with: vendorSecret)
        
        AF.request(request)
            .responseData { response in
                guard let data = response.value else {
                    return
                }
                completion(.success(data))
            }
    }
}

extension APIManager {
    struct VendorSecret: Codable {
        var secret: String = "EE5ud*rBT9Nu38_d"
    }
}
