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

let URL_GET_KEY = "https://jiocinemaapp.jio.ril.com/apis/06758e99be484fca56fb/v3/fpsdownload/getkey"
//let URL_GET_KEY = "https://jiocinemaapi-qa.jio.ril.com/fps/rest/getLicense"
//let URL_GET_CERT = "https://jiocinemaapp.jio.ril.com/apis/06758e99be484fca56fb/v3/fpsdownload/getcert"
let URL_GET_CERT                = "http://prod.media.jio.com/apis/06758e99be484fca56fb/v3/fps/getcert"



class ViewController: UIViewController {
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var persistentTypeTextfield: UITextField!
    @IBOutlet weak var playdownloadableButton: UIButton!
    
    @IBOutlet weak var downloadBUtton: UIButton!
    var jioMediaPlayer: JioMediaPlayerView?
    //let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/33/66/15a367006a1111eaa91bd94e36ab70b4.smil/index_fps3.m3u8"
    //let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/60/80/ca5f9820aa8b11ea9ab505e8b94b6f72.smil/playlist_HD_PHONE_HDP_A.m3u8"
    //let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/33/66/15a367006a1111eaa91bd94e36ab70b4.smil/index_fps4.m3u8"
    
    
    let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/26/85/244c54d066d347659996215f3e23c420.smil/playlist_voot_download.m3u8" // 15mins played
    // Done let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/14/82/32bf48f356a4400c9fdc45a42759a5d6.smil/playlist_voot_download.m3u8"
    // Done let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/23/20/23cb704e469e4a94ac159d1e14eeff14.smil/playlist_voot_download.m3u8"
    // Done let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/70/60/5aa17c573ac049c8b9ec016a49e889e7.smil/playlist_voot_download.m3u8"
    // Done let url = "http://jiovod.cdn.jio.com/vod/_definst_/smil:fps/22/62/5d3b65e594f54bb392accb1c80dcdf79.smil/playlist_voot_download.m3u8"
    
    
    
    var persistableURL: URL? {
        didSet {
            if let url = persistableURL {
                UserDefaults.standard.set(url, forKey: "persistableURL")
            }
        }
    }
    
    var persistableKey: Data? {
        didSet {
            if let key = persistableKey {
                UserDefaults.standard.set(key, forKey: "persistableKey")
            }
        }
    }
    var persistType: String = "persist_15mins"
    
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
       self.hideKeyboardWhenTappedAround()


    }
    
    @IBAction func playDownloadedItem(_ sender: Any) {
        playDownloadedAsset()
    }
    
    @IBAction func onTapDownload(_ sender: Any) {
        if self.persistentTypeTextfield.text != "" {
            self.persistType = self.persistentTypeTextfield.text!
        }
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
        self.playdownloadableButton.isUserInteractionEnabled = false
        guard let urlS = urlTextField.text, urlS != "" else {return}

        let url = URL(string: urlS)
        //let url = URL(string: <#T##String#>) //put some m3u8 url
        let headerValues = ["User-Agent" : "tizen"]
        let header  = ["AVURLAssetHTTPHeaderFieldsKey" : headerValues]
        let avasset = AVURLAsset(url: url!, options: header)
        let task = avasseturlSession.makeAssetDownloadTask(asset: avasset, assetTitle: "BipBop", assetArtworkData: nil, options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000])
        task?.resume()
    }
    
    func playDownloadedAsset() {
        let url = UserDefaults.standard.url(forKey: "persistableURL")
        if url == nil {
            return
        }
        let key = UserDefaults.standard.data(forKey: "persistableKey")
        if key == nil {
            return
        }
        resetPlayer()
        let mediaPlayerView = JioMediaPlayerView(frame: playerView.frame)
        jioMediaPlayer = mediaPlayerView
        jioMediaPlayer?.delegateToVideoOverlayController = self
        jioMediaPlayer?.addAsSubViewWithConstraints(playerView)
        playerView.bringSubviewToFront(mediaPlayerView)
        jioMediaPlayer?.configurePlayerView()
        
        jioMediaPlayer?.isDownloadedFPSContent = true
        jioMediaPlayer?.fpsPersistableKey = key!
        jioMediaPlayer?.configureFPSDownloadedContentURL(url: url!, completion: { (isplay) in
            if isplay {
                self.jioMediaPlayer?.mediaPlayer?.play()
            } else {
                print("can't play content")
            }
        })
    }
    
    
    
    @IBAction func onTapPlayButton(_ sender: Any) {
        playVideoOnView()
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
        guard let url = urlTextField.text, url != "" else {return}
        self.jioMediaPlayer?.playVideo(with: url, completion: { [weak self] (_) in
            guard let self = self else {return}
            self.jioMediaPlayer?.mediaPlayer?.isMuted = false
            self.jioMediaPlayer?.mediaPlayer?.play()
        })
    }
    
    func playVideoUsingContentKeySession() {
        
    }
}
    

extension ViewController: JioMediaPlayerDelgate {
    func itemIsReadyToPlay() {
        print("content is playing")
    }
}

extension ViewController: AVAssetResourceLoaderDelegate {
    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
        case urlNotCorrect
        case unsupportedOS
        case keyNotFPSType
        case assetIDError
        case certUrlNotCorrect
        case keyUrlNotCorrect
    }
    
    /*
     When its a Fairplay URL, run the logic for the fairplay, else move ahead with the further implementation for .ts and .m3u8
     */
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard #available(iOS 11.2, *) else {
            loadingRequest.finishLoading(with: ProgramError.unsupportedOS)
            return false
        }
    
        let URL_SCHEME_NAME = "skd"
        let url: URL? = loadingRequest.request.url
        // Must be a non-standard URI scheme for AVFoundation to invoke your AVAssetResourceLoader delegate
        // for help in loading it.
        if let urlScheme = url?.scheme, (urlScheme !=  URL_SCHEME_NAME) {
            loadingRequest.finishLoading(with: ProgramError.keyNotFPSType)
            return false
        }
        
        
        loadingRequest.contentInformationRequest?.contentType = AVStreamingKeyDeliveryPersistentContentKeyType
        
        
        let assetStr: String = url?.host ?? ""
        guard let assetStrBytes = assetStr.cString(using: String.Encoding.utf8) else {
            loadingRequest.finishLoading(with: ProgramError.assetIDError)
                       return false
        }
        
        
        let assetId = Data(bytes: assetStrBytes, count: assetStr.lengthOfBytes(using: String.Encoding.utf8))
        
        self.getAppCertificateData {[weak self] (certificate, err) in
            guard let self = self else {return}
            guard err == nil else {
                loadingRequest.finishLoading(with: err)
                return
            }
            
            do {
                
                let requestBytes = try loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: assetId, options: [AVAssetResourceLoadingRequestStreamingContentKeyRequestRequiresPersistentKey: true])
                
                self.getContentKeyAndLeaseExpiry(requestBytes: requestBytes, assetStr: assetStr, expiryDuration: 0, error: nil) { (ckcData, err) in
                    if err != nil {
                        loadingRequest.finishLoading(with: err)
                        return
                    }
                    if let ckcData = ckcData {
                        do {
                            let persistentKey = try loadingRequest.persistentContentKey(fromKeyVendorResponse: ckcData, options: nil)
                            self.persistableKey = persistentKey
                            //Call to download asset
                            DispatchQueue.main.async {
                                self.startContentDownload()
                            }
                            loadingRequest.dataRequest?.respond(with: persistentKey)
                            loadingRequest.finishLoading()
                        } catch {
                            loadingRequest.finishLoading(with: error)
                        }
                        
                    } else {
                        loadingRequest.finishLoading(with: ProgramError.noCKCReturnedByKSM)
                    }
                }
            } catch {
                loadingRequest.finishLoading(with: error)
            }
            
        }
        
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return true
    }
    
    func getAppCertificateData(completionHandler: @escaping (Data, Error?) -> Void) {
            guard let url = URL(string: URL_GET_CERT) else {
                completionHandler(Data(), ProgramError.certUrlNotCorrect)
                return
            }
            let req = NSMutableURLRequest(url: url)
            let session = URLSession.shared
            let task = session.dataTask(with: req as URLRequest, completionHandler: {data, _, error -> Void in
                if error != nil {
                    completionHandler(Data(), error)
                    return
                }
                if let dataFromServer = data {
                    if let decodedData: NSData = NSData.init(base64Encoded: dataFromServer, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) {
                        completionHandler(decodedData as Data, nil)
                        return
                    }
                }
                completionHandler(Data(), ProgramError.missingApplicationCertificate)
                
            })
            task.resume()
        }
        
        func getContentKeyAndLeaseExpiry( requestBytes: Data,
                                          assetStr: String,
                                          expiryDuration: TimeInterval,
                                          error: Error?,
                                          completionHandler: @escaping(Data?, Error?) -> ())
        {
            let dict: [AnyHashable: Any] = [
                "spc" : requestBytes.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0)),
                "id" : "JioCinemaID",
                "type": self.persistType,
                
                //"type": "persist_rental",
                //"type": "persist_unlimited30",
                
                "leaseExpiryDuration" : Double(expiryDuration)
            ]
            let jsonData: Data? = try? JSONSerialization.data(withJSONObject: dict, options: [])
          
            guard let url = URL(string: URL_GET_KEY) else {
                completionHandler(nil, ProgramError.keyUrlNotCorrect)
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
                    completionHandler(data, error)
                    return
                }
                if (data != nil), let decodedData = Data(base64Encoded: data!, options: []) {
                    completionHandler(decodedData, nil)
                } else {
                    completionHandler(data, nil)
                }
            })
            task.resume()
        }

}

extension ViewController: AVAssetDownloadDelegate {
    //MARK: Delegates
       public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL){
           print("DownloadedLocation:\(location.absoluteString)")
        self.playdownloadableButton.backgroundColor = .green
        self.playdownloadableButton.isUserInteractionEnabled = true
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
            DispatchQueue.main.async {
                self.progressLabel.text = "\(progress)"

            }
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
// Put this piece of code anywhere you like
extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
