//
//  AVContentKeySessionHandler.swift
//  JioCinema
//
//  Created by Manas Mishra on 19/06/20.
//  Copyright © 2020 Amardeep Bikkad. All rights reserved.
//

import UIKit
import AVKit

class AVContentKeySessionHandler: NSObject {
    
    // MARK: Types
    
    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
        case urlNotCorrect
    }
    
    // MARK: Properties
    
    /// The directory that is used to save persistable content keys.
    lazy var contentKeyDirectory: URL = {
        guard let documentPath =
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
                fatalError("Unable to determine library URL")
        }
        
        let documentURL = URL(fileURLWithPath: documentPath)
        
        let contentKeyDirectory = documentURL.appendingPathComponent(".keys", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: contentKeyDirectory.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: contentKeyDirectory,
                                                        withIntermediateDirectories: false,
                                                        attributes: nil)
            } catch {
                fatalError("Unable to create directory for content keys at path: \(contentKeyDirectory.path)")
            }
        }
        
        return contentKeyDirectory
    }()
    
    /// A set containing the currently pending content key identifiers associated with persistable content key requests that have not been completed.
    var pendingPersistableContentKeyIdentifiers = Set<String>()
    
}

extension AVContentKeySessionHandler: AVContentKeySessionDelegate {
    @available(iOS 10.3, *)
    func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        
    }
    
    @available(iOS 10.3, *)
    func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
        
    }
    
    @available(iOS 10.3, *)
    func contentKeySession(_ session: AVContentKeySession, shouldRetry keyRequest: AVContentKeyRequest, reason retryReason: AVContentKeyRequest.RetryReason) -> Bool {
        return false
    }
    
    
}

@available(iOS 11.2, *)
extension AVContentKeySessionHandler {
    func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
            let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString),
            let assetIDString = contentKeyIdentifierURL.host,
            let assetIDData = assetIDString.data(using: .utf8)
            else {
                print("Failed to retrieve the assetID from the keyRequest!")
                return
        }
        
        let provideOnlinekey: () -> Void = { () -> Void in
            
            do {
                let applicationCertificate = try self.requestApplicationCertificate()
                
                let completionHandler = { [weak self] (spcData: Data?, error: Error?) in
                    guard let strongSelf = self else { return }
                    if let error = error {
                        keyRequest.processContentKeyResponseError(error)
                        return
                    }
                    
                    guard let spcData = spcData else { return }
                    
                    do {
                        // Send SPC to Key Server and obtain CKC
                        let ckcData = try strongSelf.requestContentKeyFromKeySecurityModule(spcData: spcData, assetID: assetIDString, expiryDuration: 0)
                        
                        /*
                         AVContentKeyResponse is used to represent the data returned from the key server when requesting a key for
                         decrypting content.
                         */
                        let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                        
                        /*
                         Provide the content key response to make protected content available for processing.
                         */
                        keyRequest.processContentKeyResponse(keyResponse)
                    } catch {
                        keyRequest.processContentKeyResponseError(error)
                    }
                }
                
                keyRequest.makeStreamingContentKeyRequestData(forApp: applicationCertificate,
                                                              contentIdentifier: assetIDData,
                                                              options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                                                              completionHandler: completionHandler)
            } catch {
                keyRequest.processContentKeyResponseError(error)
            }
        }
        
        if #available(iOS 11.2, *) {
            /*
             When you receive an AVContentKeyRequest via -contentKeySession:didProvideContentKeyRequest:
             and you want the resulting key response to produce a key that can persist across multiple
             playback sessions, you must invoke -respondByRequestingPersistableContentKeyRequest on that
             AVContentKeyRequest in order to signal that you want to process an AVPersistableContentKeyRequest
             instead. If the underlying protocol supports persistable content keys, in response your
             delegate will receive an AVPersistableContentKeyRequest via -contentKeySession:didProvidePersistableContentKeyRequest:.
             */
            if shouldRequestPersistableContentKey(withIdentifier: assetIDString) ||
                persistableContentKeyExistsOnDisk(withContentKeyIdentifier: assetIDString) {
                
                // Request a Persistable Key Request.
                do {
                    try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
                } catch {
                    
                    /*
                     This case will occur when the client gets a key loading request from an AirPlay Session.
                     You should answer the key request using an online key from your key server.
                     */
                    provideOnlinekey()
                }
                
                return
            }
        } else {
            // Fallback on earlier versions
        }
        
        provideOnlinekey()
    }
    
}

extension AVContentKeySessionHandler {
    /// Returns whether or not a content key should be persistable on disk.
    ///
    /// - Parameter identifier: The asset ID associated with the content key request.
    /// - Returns: `true` if the content key request should be persistable, `false` otherwise.
    func shouldRequestPersistableContentKey(withIdentifier identifier: String) -> Bool {
        return pendingPersistableContentKeyIdentifiers.contains(identifier)
    }
    
    /// Returns whether or not a persistable content key exists on disk for a given content key identifier.
    ///
    /// - Parameter contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    /// - Returns: `true` if the key exists on disk, `false` otherwise.
    func persistableContentKeyExistsOnDisk(withContentKeyIdentifier contentKeyIdentifier: String) -> Bool {
        let contentKeyURL = urlForPersistableContentKey(withContentKeyIdentifier: contentKeyIdentifier)
        
        return FileManager.default.fileExists(atPath: contentKeyURL.path)
    }
    
    // MARK: Private APIs
    
    /// Returns the `URL` for persisting or retrieving a persistable content key.
    ///
    /// - Parameter contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    /// - Returns: The fully resolved file URL.
    func urlForPersistableContentKey(withContentKeyIdentifier contentKeyIdentifier: String) -> URL {
        return contentKeyDirectory.appendingPathComponent("\(contentKeyIdentifier)-Key")
    }
    
    /// Writes out a persistable content key to disk.
    ///
    /// - Parameters:
    ///   - contentKey: The data representation of the persistable content key.
    ///   - contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    /// - Throws: If an error occurs during the file write process.
    func writePersistableContentKey(contentKey: Data, withContentKeyIdentifier contentKeyIdentifier: String) throws {
        
        let fileURL = urlForPersistableContentKey(withContentKeyIdentifier: contentKeyIdentifier)
        
        try contentKey.write(to: fileURL, options: Data.WritingOptions.atomicWrite)
    }
}

extension AVContentKeySessionHandler {
    
    func requestApplicationCertificate() throws -> Data {
        
        // MARK: ADAPT - You must implement this method to retrieve your FPS application certificate.
        guard let url = URL(string: URL_GET_CERT) else {
            throw ProgramError.urlNotCorrect
        }
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        var applicationCertificate: Data!
        
        let req = NSMutableURLRequest(url: url)
        let session = URLSession.shared
        let task = session.dataTask(with: req as URLRequest, completionHandler: {data, _, error -> Void in
            
            if error != nil, let dataFromServer = data {
                if let decodedData: NSData = NSData.init(base64Encoded: dataFromServer, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) {
                    applicationCertificate = decodedData as Data
                }
            }
            dispatchGroup.leave()
        })
        task.resume()
        
        dispatchGroup.wait()
        
        
        
        guard applicationCertificate != nil else {
            throw ProgramError.missingApplicationCertificate
        }
        
        return applicationCertificate!
    }
    
    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String, expiryDuration: TimeInterval) throws -> Data {
        
        // MARK: ADAPT - You must implement this method to request a CKC from your KSM.
        guard let url = URL(string: URL_GET_KEY) else {
            throw ProgramError.urlNotCorrect
        }
        
        var ckcData: Data? = nil
        
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        let dict: [AnyHashable: Any] = [
            "spc" : spcData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)),
            "id" : "JioCinemaID",
            //"type": "persist_unlimited",
            
            //"type": "persist_rental",
            //"type": "persist_unlimited30",
            
            "leaseExpiryDuration" : Double(expiryDuration)
        ]
        let jsonData: Data? = try? JSONSerialization.data(withJSONObject: dict, options: [])

        
        let req = NSMutableURLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("\(UInt((jsonData?.count ?? 0)))", forHTTPHeaderField: "Content-Length")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        req.httpBody = jsonData
        
        let session = URLSession.shared
        let task = session.dataTask(with: req as URLRequest, completionHandler: {data, _, error -> Void in
            if error != nil {
                dispatchGroup.leave()
                return
            }
            if (data != nil), let decodedData = Data(base64Encoded: data!, options: []) {
               ckcData = decodedData
            } else {
               ckcData = data
            }
            dispatchGroup.leave()
        })
        task.resume()
        
        dispatchGroup.wait()
        
        guard ckcData != nil else {
            throw ProgramError.noCKCReturnedByKSM
        }
        
        return ckcData!
    }
    
}
