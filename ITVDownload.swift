//
//  ITVDownload.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 1/1/18.
//

import Foundation
import Kanna

public class ITVDownload : OldITVDownload {
    
    var authURL: String = ""
    var durationInSeconds: Int = 0
    var elapsedInSeconds: Int = 0
    
    public override var description: String {
        return "ITV Download (ID=\(show.pid))"
    }
    
    @objc public override init() {
        super.init()
        // Nothing to do here.
    }
    
    @objc public init(programme: Programme, formats: [TVFormat]?, proxy: HTTPProxy?, logger: LogController) {
        super.init(logController: logger)
        self.proxy = proxy
        self.show = programme
        self.attemptNumber=1
        self.defaultsPrefix = "ITV_"
        self.running = true

//        guard let formats = formats, formats.count > 0 else {
//            print("ERROR: ITV Format List is empty")
//            add(toLog: "ERROR: ITV Format List is empty")
//            show.reasonForFailure = "ITVFormatListEmpty"
//            show.complete = true
//            show.successful = false
//            show.setValue("Download Failed", forKey:"status")
//            NotificationCenter.default.post(name:NSNotification.Name(rawValue: "DownloadFinished"), object:self.show)
//            return
//        }
        
        setCurrentProgress("Retrieving Programme Metadata... \(show.showName)")
        setPercentage(102)
        programme.setValue("Initialising...", forKey: "status")
        
//        formatList = formats
        add(toLog: "Downloading \(show.showName)")
        add(toLog: "INFO: Preparing Request for Auth Info", noTag: true)
        
        DispatchQueue.main.async {
            self.launchMetaRequest()
        }
    }

    @objc public override func launchMetaRequest() {
        self.errorCache = NSMutableString()
        self.processErrorCache = Timer(timeInterval:0.25, target:self, selector:#selector(processError), userInfo:nil, repeats:true)
        
        guard let requestURL = URL(string: show.url) else {
            return
        }
        
        self.currentRequest.cancel()
        var downloadRequest = URLRequest(url:requestURL)
        
        downloadRequest.timeoutInterval = 10
        self.session = URLSession.shared
        
        if let proxy = self.proxy {
            // Create an NSURLSessionConfiguration that uses the proxy
            var proxyDict: [String: Any] = [kCFProxyTypeKey as String : kCFProxyTypeHTTP as String,
                                            kCFNetworkProxiesHTTPEnable as String : 1,
                                            kCFStreamPropertyHTTPProxyHost as String : proxy.host,
                                            kCFStreamPropertyHTTPProxyPort as String : proxy.port
            ]
            
            if let user = proxy.user, let password = proxy.password {
                proxyDict[kCFProxyUsernameKey as String] = user
                proxyDict[kCFProxyPasswordKey as String] = password
            }
            
            let configuration = URLSessionConfiguration.ephemeral
            configuration.connectionProxyDictionary = proxyDict
            
            // Create a NSURLSession with our proxy aware configuration
            self.session = URLSession(configuration:configuration, delegate:nil, delegateQueue:OperationQueue.main)
        }
        
        let message = "INFO: Requesting Metadata."
        print(message)
        if (self.verbose) {
            add(toLog:message, noTag:true)
        }
        
        self.currentRequest = self.session.dataTask(with: downloadRequest, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) in
            if let httpResponse = response as? HTTPURLResponse {
                self.metaRequestFinished(response: httpResponse,
                                         data: data,
                                         error: error)
                
            }
        })
        self.currentRequest.resume()
    }
    
    func metaRequestFinished(response: HTTPURLResponse, data: Data?, error: Error?) {
        guard self.running else {
            return
        }
        
        guard response.statusCode != 0 || response.statusCode == 200, let data = data, let responseString = String(data:data, encoding:.utf8) else {
            var message: String = ""
            
            if response.statusCode == 0 {
                message = "ERROR: No response received (probably a proxy issue): \(error?.localizedDescription ?? "Unknown error")"
                self.show.reasonForFailure = "Internet_Connection"
                self.show.setValue("Failed: Bad Proxy", forKey:"status")
            } else {
                message = "ERROR: Could not retrieve programme metadata: \(error?.localizedDescription ?? "Unknown error")"
                self.show.setValue("Download Failed", forKey:"status")
            }
            
            self.show.successful = false
            self.show.complete = true
            print(message)
            add(toLog: message)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
            add(toLog:"Download Failed", noTag:false)
            return
        }
        
        
        let message = "DEBUG: Metadata response status code: \(response.statusCode)"
        print(message)
        
        if verbose {
            add(toLog: message, noTag: true)
        }

        /*********************
         <meta property="og:description" content="James ends his epic coast-to-coast exploration of the USA with a visit to New York City.">

         <div id="video" class="genie-container js-video"
         data-genie-id="player1"
         data-video-variants="[[&quot;mpeg-dash&quot;,&quot;clearkey&quot;],[&quot;mpeg-dash&quot;,&quot;clearkey&quot;,&quot;outband-webvtt&quot;],[&quot;hls&quot;,&quot;aes&quot;,&quot;outband-webvtt&quot;],[&quot;hls&quot;,&quot;aes&quot;],[&quot;mpeg-dash&quot;,&quot;playready&quot;],[&quot;mpeg-dash&quot;,&quot;playready&quot;,&quot;outband-webvtt&quot;]]"
         data-video-channel-id="itv"
         data-video-id="https://magni.itv.com/playlist/itvonline/ITV/2_5468_0020.001"
         data-video-production-id="2/5468/0020#001"
         data-video-autoplay-id="2/5468/0020#001"
         data-video-type="episode"
         data-video-on-air-time=""
         data-video-episode-id="2/5468/0020"
         data-video-programme-id="2/5468"
         data-video-validate-region="true"
         data-video-guidance=""
         data-video-title="James Martin's American Adventure"
         data-registration-required="true"
         data-video-episode="Episode 20"
         data-video-broadcast-date-time="Friday 9 Mar 2pm"
         data-base-path="/hub/assets/js/lib/wizard/20180314073308"
         data-video-hmac="626de090726a57d5085db28bf0f8fa13f29e3809"
         data-video-posterframe="https://hubimages.itv.com/episode/2_5468_0020?w={width}&amp;h={height}&amp;q={quality}&amp;blur={blur}&amp;bg={bg}"
         data-playlist-url="https://secure-mercury.itv.com/PlaylistService.svc?wsdl"
         data-cast-enabled="true"
         data-moat-tracking-enabled="false"
         data-meetrics-tracking-enabled="false"
         data-show-error-messages="false"></div>
        *******************/
        
        var seriesName = ""
        var playlistURLString: String? = nil
        var hmac: String? = nil
        var episode = ""
        var showDescription = ""
        var timeString: String? = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT:0)

        if let htmlPage = try? HTML(html: responseString, encoding: .utf8) {
            // There should only be one 'video' element.
            if let videoElement = htmlPage.at_xpath("//div[@id='video']") {
                hmac = videoElement.at_xpath("//@data-video-hmac")?.text ?? ""
                playlistURLString = videoElement.at_xpath("//@data-video-id")?.text ?? ""
                seriesName = videoElement.at_xpath("//@data-video-title")?.text ?? "Unknown"
                episode = videoElement.at_xpath("//@data-video-episode")?.text ?? ""
            }
            
            if let descriptionElement = htmlPage.at_xpath("//script[@id='json-ld']") {
                if let descriptionJSON = descriptionElement.content {
                    if let data = descriptionJSON.data(using: .utf8) {
                        if let descJSONDict = try? JSONSerialization.jsonObject(with: data) as? [String : Any] {
                            showDescription = descJSONDict? ["description"] as? String ?? "None available"
                            
                            /*******************
                             "image": {
                             "@type": "ImageObject",
                             "height": 576,
                             "url": "https://hubimages.itv.com/episode/2_5468_0020?w=1024&h=576&q=80&blur=0&bg=false&image_format=jpg",
                             "width": 1024
                             },
                             ************/
                            if let imageDict = descJSONDict? ["image"] as? [String : Any],
                                let thumbnailURLString = imageDict["url"] as? String {
                                self.thumbnailURL = thumbnailURLString
                            }

                        }
                    }
                }
            }
            
            if let timeElement = htmlPage.at_xpath("//li[@class='episode-info__meta-item episode-info__meta-item--broadcast  episode-info__meta-item--pipe-after']/time") {
                timeString = timeElement.at_xpath("@datetime")?.text ?? ""
            }
        }

        // Save off the pieces we care about.
        self.show.seriesName = seriesName
        self.show.desc = showDescription
        self.show.episodeName = episode        
        self.thumbnailURL = thumbnailURL ?? nil
        
        if let timeString = timeString {
            self.show.standardizedAirDate = timeString
        }
        
        /*
         ios_playlist_url = params.get('data-video-playlist') or params.get('data-video-id')
         hmac = params.get('data-video-hmac')
         if ios_playlist_url and hmac and re.match(r'https?://', ios_playlist_url):
         headers = self.geo_verification_headers()
         headers.update({
         'Accept': 'application/vnd.itv.vod.playlist.v2+json',
         'Content-Type': 'application/json',
         'hmac': hmac.upper(),
         })
         ios_playlist = self._download_json(
         ios_playlist_url, video_id, data=json.dumps({
         'user': {
         'itvUserId': '',
         'entitlements': [],
         'token': ''
         },
         'device': {
         'manufacturer': 'Safari',
         'model': '5',
         'os': {
         'name': 'Windows NT',
         'version': '6.1',
         'type': 'desktop'
         }
         },
         'client': {
         'version': '4.1',
         'id': 'browser'
         },
         'variantAvailability': {
         'featureset': {
         'min': ['hls', 'aes', 'outband-webvtt'],
         'max': ['hls', 'aes', 'outband-webvtt']
         },
         'platformTag': 'dotcom'
         }
         }).encode(), headers=headers, fatal=False)
         */

        add(toLog:"INFO: Metadata processed.", noTag:true)
        
        //Create Download Path
        self.createDownloadPath()
        self.show.path = self.downloadPath

        var mediaBaseURL: String? = nil, mediaHREF: String? = nil
        
        if let playlistURLString = playlistURLString, let playlistURL = URL(string: playlistURLString) {
            var playlistRequest = URLRequest(url: playlistURL)
            playlistRequest.setValue("application/vnd.itv.vod.playlist.v2+json", forHTTPHeaderField: "Accept")
            playlistRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let hmac = hmac {
                playlistRequest.setValue(hmac.uppercased(), forHTTPHeaderField: "hmac")
            }
            
            playlistRequest.httpMethod = "POST"

            let requestBody = "{ \"user\": { \"itvUserId\": \"\", \"entitlements\": [], \"token\": \"\" }, \"device\": { \"manufacturer\": \"Safari\", \"model\": \"11\", \"os\": { \"name\": \"Windows NT\", \"version\": \"6.1\", \"type\": \"desktop\" } }, \"client\": { \"version\": \"4.1\", \"id\": \"browser\" }, \"variantAvailability\": { \"featureset\": { \"min\": [\"aes\", \"hls\", \"outband-webvtt\"], \"max\": [\"hls\", \"aes\", \"outband-webvtt\"] }, \"platformTag\": \"dotcom\" } }"

            let requestData = requestBody.data(using: .utf8)
            playlistRequest.httpBody = requestData
            
            self.currentRequest = self.session.dataTask(with: playlistRequest, completionHandler: {
                (data: Data?, response: URLResponse?, error: Error?) in
                guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                    return
                }
                if httpResponse.statusCode != 200 {
                    if httpResponse.statusCode == 404 {
                        self.add(toLog:"ERROR: ITV couldn't find a version of the program we can download.")
                        self.show.reasonForFailure = "ShowNotFound"
                    } else if httpResponse.statusCode == 403 {
                        self.add(toLog:"ERROR: ITV has determined you are outside the UK.")
                        self.show.reasonForFailure = "Outside_UK"
                    }
                    
                    self.show.successful = false
                    self.show.complete = true
                    self.show.setValue("Download Failed", forKey:"status")
                    print(message)
                    self.add(toLog: message)
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue:"DownloadFinished"), object:self.show)
                    self.add(toLog:"Download Failed", noTag:false)
                    return
                }
                if let descJSONDict = try? JSONSerialization.jsonObject(with: data) as? [String : Any] {
                    if let playlistDict = descJSONDict?["Playlist"] as? [String : Any] {
                        if let videoDict = playlistDict["Video"] as? [String: Any] {
                            mediaBaseURL = videoDict["Base"] as? String
                            if let mediaFilesDict = videoDict["MediaFiles"] as? [[String: Any]] {
                                mediaHREF = mediaFilesDict[0]["Href"] as? String
                            }
                            if let subtitleDict = videoDict["Subtitles"] as? [[String: Any]] {
                                self.subtitleURL = subtitleDict[0]["Href"] as? String
                            }
                        }
                    }
                    
                }
                
                guard let mediaBaseURL = mediaBaseURL, let mediaHREF = mediaHREF, let baseURL = URL(string: mediaBaseURL) else {
                    return
                }
                
                if let mediaURL = URL(string: mediaHREF, relativeTo: baseURL) {
                    DispatchQueue.main.async {
                        self.launchFFMPEG(url: mediaURL.absoluteString)
                    }
                }
            })
            
            self.currentRequest.resume()
        } else {
            add(toLog:"ERROR: Couldn't find playlist information on show page.")
            self.show.reasonForFailure = "ShowNotFound";
            self.show.complete = true;
            self.show.successful = false;
            self.show.setValue("Download Failed", forKey:"status")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "DownloadFinished"), object:self.show)
            return
        }
    }
    
    fileprivate func convertToSeconds(_ timeString: String) -> Int {
        let timeParts = timeString.split {($0 == ":") || ($0 == ".")}
        var timeInSeconds = 0
        for (i, d) in timeParts.enumerated() {
            if let x = Int(d) {
                switch (i) {
                case 0:
                    timeInSeconds += x * 60 * 60
                case 1:
                    timeInSeconds += x * 60
                case 2:
                    timeInSeconds += x
                default:
                    break
                    // Don't worry about fractions.
                }
            }
        }
        
        return timeInSeconds
    }
    
    @objc public func ffmpegProgress(progress: Notification?) {
        if let data = progress?.userInfo?[NSFileHandleNotificationDataItem] as? Data, data.count > 0,
            let s = String(data: data, encoding: .utf8) {
            
            // ffmpeg generates a lot of garbage due to the nature of streaming, so filter out what we care about.
            if !s.contains("Invalid") {
                if self.verbose && (s.contains("Duration:") || s.contains("time=")) && !s.hasPrefix("[") {
                    self.logger.add(toLog: s, self)
                }
                // ffmpeg progress line:
                //   Duration: 00:46:17.16, start: 10.000000, bitrate: 0 kb/s
                // frame=   61 fps=0.0 q=28.0 size=       0kB time=00:00:02.53 bitrate=   0.2kbits/s speed=4.98x
                let scanner: Scanner
                var duration: String? = nil
                var elapsed: String? = nil
                if s.contains("Duration:") {
                    scanner = Scanner(string: s)
                    scanner.scanUpToString("Duration:")
                    scanner.scanString("Duration:")
                    duration = scanner.scanUpToString(",")?.trimmingCharacters(in: .whitespaces)
                } else if s.contains("time=") {
                    scanner = Scanner(string: s)
                    scanner.scanUpToString("time=")
                    scanner.scanString("time=")
                    elapsed = scanner.scanUpToString(" ")?.trimmingCharacters(in: .whitespaces)
                }
                
                if let duration = duration {
                    durationInSeconds = convertToSeconds(duration)
                }
                if let elapsed = elapsed {
                    elapsedInSeconds = convertToSeconds(elapsed)
                }
                
                if elapsedInSeconds != 0 && durationInSeconds != 0 {
                    setPercentage(100.0 * Double(elapsedInSeconds) / Double(durationInSeconds))
                }
            }
            fh?.readInBackgroundAndNotify()
            errorFh?.readInBackgroundAndNotify()
        }
    }
    
    @objc public func ffmpegFinishedDownload() {
        if let tagOption = UserDefaults.standard.object(forKey: "TagShows") as? Bool, tagOption {
            self.show.status = "Downloading Thumbnail..."
            setPercentage(102)
            setCurrentProgress("Downloading Thumbnail... -- \(show.showName)")
            if let thumbnailURL = thumbnailURL {
                add(toLog: "INFO: Downloading thumbnail", noTag: true)
                thumbnailPath = URL(fileURLWithPath: show.path).appendingPathExtension("jpg").path
                let downloadTask: URLSessionDownloadTask? = session.downloadTask(with: URL(string: thumbnailURL)!, completionHandler: {(_ location: URL?, _ response: URLResponse?, _ error: Error?) -> Void in
                    self.thumbnailRequestFinished(location)
                })
                downloadTask?.resume()
            }
            else {
                thumbnailRequestFinished(nil)
            }
        }
        else {
            atomicParsleyFinished(nil)
        }
    }
    
    private func launchFFMPEG(url: String) {
        setCurrentProgress("Downloading \(show.showName)")
        setPercentage(102)
        show.setValue("Downloading...", forKey: "status")

        task = Process()
        pipe = Pipe()
        errorPipe = Pipe()
        task?.standardInput = FileHandle.nullDevice
        task?.standardOutput = pipe
        task?.standardError = errorPipe
        fh = pipe?.fileHandleForReading
        errorFh = errorPipe?.fileHandleForReading

        let args: [String] = ["-i",
                              url,
                              "-y",
                              downloadPath]
        if self.verbose {
            self.logDebugMessage("DEBUG: ffmpeg args:\(args)", noTag: true)
        }

        if let executableURL = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("ffmpeg") {
            task?.launchPath = executableURL.path
            task?.arguments = args
            NotificationCenter.default.addObserver(self, selector: #selector(self.ffmpegProgress), name: FileHandle.readCompletionNotification, object: fh)
            NotificationCenter.default.addObserver(self, selector: #selector(self.ffmpegProgress), name: FileHandle.readCompletionNotification, object: errorFh)

            task?.terminationHandler = {
                task in
                self.add(toLog: "ffmpeg finished downloading")
                self.processErrorCache.invalidate()
                
                let exitCode = task.terminationStatus
                if exitCode == 0 {
                    self.show.complete = (true)
                    self.show.successful = (true)
                    let info = ["Programme" : self.show]
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AddProgToHistory"), object:self, userInfo:info)
                        self.ffmpegFinishedDownload()
                    }
                }
            }

            task?.launch()
            fh?.readInBackgroundAndNotify()
            errorFh?.readInBackgroundAndNotify()
        }
    }
}
