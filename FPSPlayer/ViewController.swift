//
//  ViewController.swift
//  FPSPlayer
//
//  Created by Amardeep Bikkad on 11/03/20.
//  Copyright © 2020 Amardeep Bikkad. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    
    @IBOutlet weak var downloadBUtton: UIButton!
    var jioMediaPlayer: JioMediaPlayerView?
    let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/33/66/15a367006a1111eaa91bd94e36ab70b4.smil/index_fps3.m3u8"
    
    var persistableURL: URL?
    
    var persistableKey: Data?
    
    var videoAsset : AVURLAsset?
    
    private lazy var avasseturlSession: AVAssetDownloadURLSession = {
          let config = URLSessionConfiguration.background(withIdentifier: "MySession")
          config.isDiscretionary = true
          config.sessionSendsLaunchEvents = true
          return AVAssetDownloadURLSession(configuration: config,assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
      }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    @IBAction func onTapDownload(_ sender: Any) {
        let videoURLStr = self.url
        guard let videoUrl = URL(string: videoURLStr) else{return}
        //let headerValues = ["ssotoken" : "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1bmlxdWUiOiI4ZWQ2MDI2Ny0wYTdmLTRiZGItODFkMS1lZWYwMDU2YTUxMTkiLCJ1c2VyVHlwZSI6IlJJTHBlcnNvbiIsImF1dGhMZXZlbCI6IjMwIiwiZGV2aWNlSWQiOiI0Njc2NDU0OTc4NWQ1NDE0Zjg0YTEwODc1ZGYzNjZiNDlhZjM2ZGJkYjQ5ZTliNDMyMDRlNDljN2U2NGNlOGMwMTIyZTQwMzBjNGQ5MTkyODU3OTRlNmRjOGYxN2Y2NmM3MjZjMmQwOTNhYzQ4M2MxZDY2OWQ4YmY3YjkxYjYyMSIsImp0aSI6ImEwNDJjZTU4LWYwYWYtNDFiYS05ODA4LTVlNTFhOWJkZGZjNCIsImlhdCI6MTU4MzkxMDUyOH0.AWKnFWh7KiYjUVcYriKPHYUPs2FNnCzX7rFV2K6JENY"]
        let headerValues = ["User-Agent" : "tizen"]
        let header = ["AVURLAssetHTTPHeaderFieldsKey" : headerValues]
        self.videoAsset = AVURLAsset(url: videoUrl, options: header)
         self.videoAsset?.resourceLoader.preloadsEligibleContentKeys = true
         self.videoAsset?.resourceLoader.setDelegate(self, queue: DispatchQueue(label: "jioCinema-delegateQueue"))
        //startContentDownload()
        
    }
    
    func startContentDownload() {
        let url = URL(string: self.url)
        //let url = URL(string: <#T##String#>) //put some m3u8 url
        let headerValues = ["User-Agent" : "tizen"]
        let header  = ["AVURLAssetHTTPHeaderFieldsKey" : headerValues]
        let avasset = AVURLAsset(url: url!, options: header)
        let task = avasseturlSession.makeAssetDownloadTask(asset: avasset, assetTitle: "BipBop", assetArtworkData: nil, options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000])
        task?.resume()
    }
    
    func playDownloadedAsset() {
        resetPlayer()
        let mediaPlayerView = JioMediaPlayerView(frame: playerView.frame)
        jioMediaPlayer = mediaPlayerView
        jioMediaPlayer?.delegateToVideoOverlayController = self
        jioMediaPlayer?.addAsSubViewWithConstraints(playerView)
        playerView.bringSubviewToFront(mediaPlayerView)
        jioMediaPlayer?.configurePlayerView()
        
        jioMediaPlayer?.isDownloadedFPSContent = true
        jioMediaPlayer?.fpsPersistableKey = persistableKey
        jioMediaPlayer?.configureFPSDownloadedContentURL(url: self.persistableURL!, completion: { (isplay) in
            if isplay {
                self.jioMediaPlayer?.mediaPlayer?.play()
            } else {
                print("can't play content")
            }
        })
    }
    
    
    
    @IBAction func onTapPlayButton(_ sender: Any) {
        //playVideoOnView()
    }
    
    func playVideoOnView() {
        resetPlayer()
        let mediaPlayerView = JioMediaPlayerView(frame: playerView.frame)
        jioMediaPlayer = mediaPlayerView
        jioMediaPlayer?.delegateToVideoOverlayController = self
        jioMediaPlayer?.addAsSubViewWithConstraints(playerView)
        playerView.bringSubviewToFront(mediaPlayerView)
        jioMediaPlayer?.configurePlayerView()
        jioMediaPlayer?.isFpsAvailable = false
        playContentInPlayer()
    }
    
    func resetPlayer() {
        jioMediaPlayer?.removeFromSuperview()
        jioMediaPlayer = nil
    }
    
    //Used to play a content by passing url to player
    private func playContentInPlayer() {
        jioMediaPlayer?.isFpsAvailable = true
        self.jioMediaPlayer?.playVideo(with: url, completion: { [weak self] (_) in
            guard let self = self else {return}
            self.jioMediaPlayer?.mediaPlayer?.isMuted = false
            self.jioMediaPlayer?.mediaPlayer?.play()
        })
    }
}
    

extension ViewController: JioMediaPlayerDelgate {
    func itemIsReadyToPlay() {
        print("content is playing")
    }
}

extension ViewController: AVAssetResourceLoaderDelegate {
    
    /*
     When its a Fairplay URL, run the logic for the fairplay, else move ahead with the further implementation for .ts and .m3u8
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        if #available(iOS 11.2, *) {
            if  let contentTypes = loadingRequest.contentInformationRequest?.allowedContentTypes,
                !contentTypes.contains(AVStreamingKeyDeliveryPersistentContentKeyType) {
                
                // Fallback to provide online FairPlay Streaming key from key server.
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

                           if let requestBytes = try? loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: assetId, options: [AVAssetResourceLoadingRequestStreamingContentKeyRequestRequiresPersistentKey: true]) {
                            self.getContentKeyAndLeaseExpiry(requestBytes: requestBytes, assetStr: assetStr, expiryDuration: 0, error: error) { (ckcData) in
                                if let ckcData = ckcData, let persistentKey = try? loadingRequest.persistentContentKey(fromKeyVendorResponse: ckcData, options: nil) {
                                    //Persist key
                                    self.persistableKey = persistentKey
                                    //Call to download asset
                                    self.startContentDownload()
                                    loadingRequest.dataRequest?.respond(with: persistentKey)
                                    loadingRequest.finishLoading()
                                }
                                
                            }
                              
                           }
                       }
                
            }
        } else {
            // Fallback on earlier versions
        }
       
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return true
    }
    func getAppCertificateData(completionHandler: @escaping (Data) -> Void) {
            let URL_GET_CERT = "http://prod.media.jio.com/apis/06758e99be484fca56fb/v3/fps/getcert"
            guard let url = URL(string: URL_GET_CERT) else {
                return
            }
            let req = NSMutableURLRequest(url: url)
    //        let ssoToken = self.appManager.getUserModel()?.ssoToken
    //        let uniqueId = self.appManager.getUserModel()?.uniqueId
    //        req.setValue(ssoToken, forHTTPHeaderField: "ssotoken")
    //        req.setValue(uniqueId, forHTTPHeaderField: "uniqueid")
    //        req.setValue(vUserGroup, forHTTPHeaderField: "usergroup")
    //        req.setValue(vUserAgent, forHTTPHeaderField: "useragent")
    //        req.setValue(vOS, forHTTPHeaderField: kOs)
    //        req.setValue(vDeviceType, forHTTPHeaderField: "devicetype")
    //        req.setValue(xAPISignature, forHTTPHeaderField: kApiSignatures)
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
            var jsonData: Data? = try? JSONSerialization.data(withJSONObject: dict, options: [])
            let URL_GET_KEY = "http://prod.media.jio.com/apis/06758e99be484fca56fb/v3/fps/getkey"
            guard let url = URL(string: URL_GET_KEY) else {
                return
            }
            let req = NSMutableURLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("\(UInt((jsonData?.count ?? 0)))", forHTTPHeaderField: "Content-Length")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    //        req.setValue(self.appManager.getUserModel()?.ssoToken, forHTTPHeaderField: "ssotoken")
    //        req.setValue(self.appManager.getUserModel()?.uniqueId, forHTTPHeaderField: kUniqueId)
    //        req.setValue(vUserGroup, forHTTPHeaderField: "usergroup")
    //        req.setValue(vUserAgent, forHTTPHeaderField: "useragent")
    //        req.setValue(vOS, forHTTPHeaderField: kOs)
    //        req.setValue(vDeviceType, forHTTPHeaderField: "devicetype")
    //        req.setValue(xAPISignature, forHTTPHeaderField: kApiSignatures)
                
            req.httpBody = jsonData
            
            let session = URLSession.shared
            let task = session.dataTask(with: req as URLRequest, completionHandler: {data, _, error -> Void in
                if error != nil {
                    
                    return
                }
                if (data != nil), let decodedData = Data(base64Encoded: data!, options: []) {
                    try? completionHandler(decodedData)
                } else {
                    try? completionHandler(data)
                }
            })
            task.resume()
        }

}

extension ViewController: AVAssetDownloadDelegate {
    //MARK: Delegates
       public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL){
           print("DownloadedLocation:\(location.absoluteString)")
        self.playButton.backgroundColor = .green
        self.persistableURL = location
       }

       public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
           print("Error")
       }

       public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
           print("Error")
       }

       public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
           print("Waiting")
       }

       public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
           print("Finihs collecting metrics:")
       }
    
   
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            print("Progress \(downloadTask) \(progress)")
            self.progressLabel.text = "\(progress)"
        }
    }
    
    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            // Calculate the percentage of the total expected asset duration
            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
            print("percentage = \(percentComplete)")
    }
    
    //Called when task completes in bg
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
//          DispatchQueue.main.async {
//              guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
//                  //let backgroundCompletionHandler =
//                  //appDelegate.backgroundCompletionHandler else {
//                      return
//              }
//            print("Completed in background")
//              backgroundCompletionHandler()
//          }
      }
    
}
