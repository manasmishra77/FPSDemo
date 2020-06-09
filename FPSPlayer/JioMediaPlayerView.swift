//
//  JioMediaAVPlayer.swift
//  JioCinema
//
//  Created by Abhishek Srivastava on 15/02/18.
//  Copyright © 2018 Reliance Jio. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

protocol JioMediaPlayerDelgate: AnyObject {
    func itemIsReadyToPlay()
}

extension JioMediaPlayerDelgate {
    func carouselTrailerIsReadyToPlay(_ playerView: JioMediaPlayerView) {}
    func itemIsReadyToPlay() {}
    func playerSeekingStarted(shouldAddIndicator: Bool, isItFromSlider: Bool) {}
    func playerTimeChanged(currentTime: Double) {}
    func mediaStartAnalyticsEvent() {}
    func playerFailedToPlay(reason: Any) {}
    func bothAesAndFpsUrlNotValidOrPresent(message: String) {}
    func playerBufferIsEmpty(shouldAddRetry: Bool) {}
    func playerBufferComplete(bufferDuration: Double, initialBufferTime:Date, bufferEndTime:Date) {}
    func playerBufferLiklyToKeep() {}
    func playerBufferFull() {}
    func addRetryViewForJioMediaPlayer(Message: String) {}
    func checkToShowSkipIntroButton(currentTime: Double) {}
}


class JioMediaPlayerView: UIView {
    var playerItem: AVPlayerItem? {
        return mediaPlayer?.currentItem
    }
    var mediaPlayer: AVPlayer? {
        guard let newlayer = self.layer as? AVPlayerLayer else {return nil}
        return newlayer.player
    }
    var avPlayerLayer: AVPlayerLayer? {
        guard let newlayer = self.layer as? AVPlayerLayer else {return nil}
        return newlayer
    }
    var mediaUrl                    = ""
    var fwdRewindOffset: Double     = 10
    var resumeWatchSeekTime: CMTime?
    var isFpsAvailable: Bool        = false
    
    var isDownloadedFPSContent: Bool = false
    var videoAsset: AVURLAsset?
    weak var delegateToVideoOverlayController: JioMediaPlayerDelgate?
    
    //Use this variable to store the clousure, which is get called in every second by the player
    var playerTimeObserverToken: Any?
    
    // used to keep indicator loading till item is not getting played
    var isSeekingCompleted = false
    
    //This variable is used to store aesHLSkey for sometime// used in resource loader delegate
    var aesHLSKey: Data?
    var fpsPersistableKey: Data?
    
    func configurePlayerView() {
        guard let newlayer = self.layer as? AVPlayerLayer else {return}
        newlayer.player = AVPlayer()
        self.avPlayerLayer?.videoGravity = .resizeAspect
    }
    
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    func removeObserverOfPlayer() {
        self.resetPeriodicTimeObserver()
        if self.playerItem != nil {
            self.playerItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            self.playerItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            self.playerItem?.removeObserver(self, forKeyPath: "playbackBufferFull")
            self.playerItem?.removeObserver(self, forKeyPath: "status")
            self.playerItem?.removeObserver(self, forKeyPath: "isPictureInPicturePossible")
            //self.playerItem = nil
        }
    }
    
    func addObserversToPlayerItem() {
        self.playerItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        self.playerItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        self.playerItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
        self.playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .old], context: nil)
        self.playerItem?.addObserver(self, forKeyPath: "isPictureInPicturePossible", options: [.new], context: nil)
    }
    
    // MARK: Handle Fairplay(FPS) Video Url
    func configureFPSStreamingUrl(completion: @escaping ((_ isPlayerReadyToPlay: Bool) -> ())) {
        guard let videoURLStr = self.mediaUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        if let videoUrl = URL.init(string: videoURLStr) {
            let headerValues = ["ssotoken" : "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1bmlxdWUiOiI4ZWQ2MDI2Ny0wYTdmLTRiZGItODFkMS1lZWYwMDU2YTUxMTkiLCJ1c2VyVHlwZSI6IlJJTHBlcnNvbiIsImF1dGhMZXZlbCI6IjMwIiwiZGV2aWNlSWQiOiI0Njc2NDU0OTc4NWQ1NDE0Zjg0YTEwODc1ZGYzNjZiNDlhZjM2ZGJkYjQ5ZTliNDMyMDRlNDljN2U2NGNlOGMwMTIyZTQwMzBjNGQ5MTkyODU3OTRlNmRjOGYxN2Y2NmM3MjZjMmQwOTNhYzQ4M2MxZDY2OWQ4YmY3YjkxYjYyMSIsImp0aSI6ImEwNDJjZTU4LWYwYWYtNDFiYS05ODA4LTVlNTFhOWJkZGZjNCIsImlhdCI6MTU4MzkxMDUyOH0.AWKnFWh7KiYjUVcYriKPHYUPs2FNnCzX7rFV2K6JENY"]
            let header = ["AVURLAssetHTTPHeaderFieldsKey" : headerValues]
            videoAsset = AVURLAsset(url: videoUrl, options: header)
            self.isAssetPlayable { (isPlayable) in
                
                if isPlayable {
                    self.videoAsset?.resourceLoader.setDelegate(self, queue: DispatchQueue(label: "jioCinema-delegateQueue"))
                    self.removeObserverOfPlayer()
                    let playerItem = AVPlayerItem.init(asset: self.videoAsset!)
                    self.mediaPlayer?.replaceCurrentItem(with: playerItem)
                    completion(true)
                    self.addObserversToPlayerItem()
                } else {
                    //guard let error = self.mediaPlayer?.currentItem?.error else {return}
                    self.delegateToVideoOverlayController?.playerFailedToPlay(reason: "Not Play")
                }
            }
        }
    }
    
    func configureFPSDownloadedContentURL(url: URL, completion: @escaping ((_ isPlayerReadyToPlay: Bool) -> ())) {
        self.videoAsset = AVURLAsset(url: url)
        self.videoAsset?.resourceLoader.setDelegate(self, queue: DispatchQueue(label: "jioCinema-delegateQueue"))
        self.removeObserverOfPlayer()
        let playerItem = AVPlayerItem.init(asset: self.videoAsset!)
        self.mediaPlayer?.replaceCurrentItem(with: playerItem)
        completion(true)
        self.addObserversToPlayerItem()
    }
    
    
    
    // MARK: - Configure Asset
    private func isAssetPlayable(completion:@escaping ((Bool) -> Void)) {
        let requireAssetKeys = ["playable", "hasProtectedContent"]

        self.videoAsset?.loadValuesAsynchronously(forKeys: requireAssetKeys, completionHandler: {() -> Void in
            DispatchQueue.main.async {
                /*
                 Test whether the values of each of the keys we need have been
                 successfully loaded.
                 */
                for key in requireAssetKeys {
                    var error: NSError?
                    if self.videoAsset?.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description",
                                                             comment: "Can't use this AVAsset because one of it's keys failed to load")
                        print(stringFormat)
                        completion(false)
                        return
                    }
                }
                // We can't play this asset.
                if !self.videoAsset!.isPlayable {
                    let userInfo: [AnyHashable: Any] = [
                        NSLocalizedDescriptionKey: NSLocalizedString("Unplayable",
                                                                     value: "Asset Not Playable", comment: "This asset is not playable") ]
                    let error: NSError = NSError(domain: "Internal", code: 8000, userInfo: userInfo as? [String: Any])
                    print("$$$$$ isPlayable  Error ", error.description)
                    completion(false)
                    return
                }
                completion(true)
            }
        })
    }
    
   
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object is AVPlayerItem {
            switch keyPath {
            case "playbackBufferEmpty"?:
                break
            case "playbackLikelyToKeepUp"?:
                break
            case "playbackBufferFull"?:
                break
                delegateToVideoOverlayController?.playerBufferFull()
            case "isPictureInPicturePossible"?:
                break
            case #keyPath(AVPlayerItem.status):
                let newStatus: AVPlayerItem.Status
                if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                    newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue) ?? .unknown
                } else {
                    newStatus = .unknown
                }
                switch newStatus {
                case .readyToPlay:
                    delegateToVideoOverlayController?.itemIsReadyToPlay()
                    delegateToVideoOverlayController?.carouselTrailerIsReadyToPlay(self)
                    self.addPlayerPeriodicTimeObserver()
                    
                case .failed:
                    guard let error = self.mediaPlayer?.currentItem?.error else {return}
                    delegateToVideoOverlayController?.playerFailedToPlay(reason: error)
                case .unknown:
                    break
                default:
                    print("JioMediaPlayerView: DefaultCase \(newStatus)")
                }
            default:
                break
            }
        }
    }
    
    func playVideo(with urlStr: String, completion: @escaping ((_ isPlayerReadyToPlay: Bool) -> ())) {
        self.mediaUrl = urlStr
        self.configureFPSStreamingUrl {[weak self] (_) in
            guard let self = self else {return}
            if let seekTime = self.resumeWatchSeekTime {
                self.mediaPlayer?.seek(to: seekTime)
            }
            self.mediaPlayer?.play()
            completion(true)
        }
    }

    deinit {
        resetPeriodicTimeObserver()
        self.mediaPlayer?.pause()
        removeObserverOfPlayer()
    }
}

//Add timeObervertaken, which is called in every second

extension JioMediaPlayerView {
    func resetPeriodicTimeObserver() {
        if let timeObserverToken = playerTimeObserverToken {
            self.mediaPlayer?.removeTimeObserver(timeObserverToken)
            playerTimeObserverToken = nil
        }
    }
    func addPlayerPeriodicTimeObserver() {
        resetPeriodicTimeObserver()
        let interval = CMTime(seconds: 1,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let mainQueue = DispatchQueue.main
        
        // Add time observer
        playerTimeObserverToken =
            self.mediaPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) { [weak self] cmTime in
                guard let self = self else {return}
                let time = cmTime.seconds
                self.delegateToVideoOverlayController?.playerTimeChanged(currentTime: time)
                self.delegateToVideoOverlayController?.checkToShowSkipIntroButton(currentTime: time)
        }
    }
}
extension JioMediaPlayerView: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        //Update video controls of main player to reflect the current state of the video playback.
        //You may want to update the video scrubber position.
        completionHandler(true)
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP will start event
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP did start event
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        //Handle PIP failed to start event
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP will stop event
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //Handle PIP did start event
    }
}
