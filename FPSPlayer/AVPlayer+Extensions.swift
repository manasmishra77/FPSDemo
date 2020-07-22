//
//  AVPlayer+Extensions.swift
//  JioCinema
//
//  Created by Abhishek Srivastava on 26/02/18.
//  Copyright © 2018 Reliance Jio. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

// MARK: AVAssetResourceLoaderDelegate Methods

extension JioMediaPlayerView: AVAssetResourceLoaderDelegate {
    
    /*
     When its a Fairplay URL, run the logic for the fairplay, else move ahead with the further implementation for .ts and .m3u8
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if self.isDownloadedFPSContent {
            return fpsDownloadableContentResourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: loadingRequest)
        }
        if self.isFpsAvailable {
            return self.fps(resourceLoader: resourceLoader, loadingRequest: loadingRequest)
        }
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return true
    }
}

extension JioMediaPlayerView {
    func fps (resourceLoader: AVAssetResourceLoader, loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        let URL_SCHEME_NAME = "skd"
        let dataRequest: AVAssetResourceLoadingDataRequest? = loadingRequest.dataRequest
        let url: URL? = loadingRequest.request.url
        let error: Error? = nil
        // Must be a non-standard URI scheme for AVFoundation to invoke your AVAssetResourceLoader delegate
        // for help in loading it.
        if let urlScheme = url?.scheme, (urlScheme !=  URL_SCHEME_NAME) {
            return false
        }
        let assetStr: String = url?.host ?? ""
        let assetId = Data(bytes: assetStr.cString(using: String.Encoding.utf8)!, count: assetStr.lengthOfBytes(using: String.Encoding.utf8))
        self.getAppCertificateData {[weak self] (certificate) in
            guard let self = self else {return}
            if let requestBytes = try? loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: assetId, options: nil) {
                self.getContentKeyAndLeaseExpiry(requestBytes: requestBytes,
                                                 assetStr: assetStr,
                                                 expiryDuration: 0,
                                                 error: error,
                                                 completionHandler: { (responseData) in
                                                    if let responseData = responseData {
                                                        dataRequest?.respond(with: responseData)
                                                        loadingRequest.finishLoading()
                                                    } else {
                                                        loadingRequest.finishLoading(with: NSError(domain: "Key fetching failed", code: 455, userInfo: nil))
                                                    }
                })
            }
        }
        return true
    }
    
    func getAppCertificateData(completionHandler: @escaping (Data) -> Void) {
       // let URL_GET_CERT = "https://jiocinemaapp.jio.ril.com/apis/06758e99be484fca56fb/v3/fps/getcert"
        guard let url = URL(string: URL_GET_CERT) else {
            return
        }
        let req = NSMutableURLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: req as URLRequest, completionHandler: {data, _, error -> Void in
            if error != nil {
                return
            }
            if let dataFromServer = data {
                if let decodedData: NSData = NSData.init(base64Encoded: dataFromServer, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) {
                    completionHandler(decodedData as Data)
                }
            }
        })
        task.resume()
    }
    
    func getContentKeyAndLeaseExpiry( requestBytes: Data,
                                      assetStr: String,
                                      expiryDuration: TimeInterval,
                                      error: Error?,
                                      completionHandler: @escaping(Data?) throws -> Void) {
        let dict: [AnyHashable: Any] = [
            "spc" : requestBytes.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)),
            "id" : "JioCinemaID",
            "leaseExpiryDuration" : Double(expiryDuration)
        ]
        let jsonData: Data? = try? JSONSerialization.data(withJSONObject: dict, options: [])
       // let URL_GET_KEY = "https://jiocinemaapp.jio.ril.com/apis/06758e99be484fca56fb/v3/fps/getkey"
        guard let url = URL(string: URL_GET_KEY) else {
            return
        }
        let req = NSMutableURLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("\(UInt((jsonData?.count ?? 0)))", forHTTPHeaderField: "Content-Length")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        req.httpBody = jsonData
        
        let session = URLSession.shared
        let task = session.dataTask(with: req as URLRequest, completionHandler: {data, _, error -> Void in
            if error != nil {
                
                return
            }
            if (data != nil), let decodedData = Data(base64Encoded: data!, options: []) {
                let str = String(decoding: data!, as: UTF8.self)
                print(str)
                try? completionHandler(decodedData)
            } else {
                try? completionHandler(data)
            }
        })
        task.resume()
    }
}


extension JioMediaPlayerView {
    func fpsDownloadableContentResourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
       loadingRequest.contentInformationRequest?.contentType = AVStreamingKeyDeliveryPersistentContentKeyType
        // Provide the content key response to make protected content available for processing.
        loadingRequest.dataRequest?.respond(with: self.fpsPersistableKey!)
        loadingRequest.finishLoading()
        return true
    }
}
