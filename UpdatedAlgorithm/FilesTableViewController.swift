//
//  FilesTableViewController.swift
//  AlgorithmIntegration
//
//  Created by Mitchell Phillips on 3/4/16.
//  Copyright © 2016 CTEC. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation

public enum SCSiriWaveformViewInputType{
    case Recorder
    case Player
}

class FilesTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    
    var userInfo = ""

    var arrayOfFiles = [AudioFile]()
    
    //MARK: - Class Variables
    
    var recorderDelegate:ISAudioRecorderViewDelegate?
    var blurEffectType:UIBlurEffectStyle?
    var leftToolBarLabelText:String?
    var rightToolBarLabelText:String?
    var soundFileTitle:String?
    var recorderLimitTime:Double?
    var toolBarTintColor:UIColor?
    var timeLimitLabelColor:UIColor?
    var innerCircleColor:UIColor?
    
    private var toolBar:UIToolbar!
    private var isRecording = false
    private var isPlaying = false
    private var waveView:SCSiriWaveformView!
    private var waveViewInputType:SCSiriWaveformViewInputType!
    private var recorder:AVAudioRecorder!
    private var player:AVAudioPlayer!
    private var soundFileURL:NSURL!
    private var displayLink:CADisplayLink!
    private var testParentViewController:UIViewController!
    private var playBtn:UIButton!
    private var stopBtn:UIButton!
    private var recorderImgBtn:UIButton!
    private var fileName:String!
    private var meterTimer:NSTimer!
    private var rightToolBarItem:UIBarButtonItem!
    private var leftToolBarItem:UIBarButtonItem!
    private var blurView: UIVisualEffectView!
    
    
    //Split sound variables
    private var startLevel, endLevel : Float!
    private var timer : NSTimer!
    private var waitTime : NSTimeInterval!


    @IBOutlet weak var fileTableView: UITableView!
    
    @IBAction func stopButton(sender: UIButton) {
        
        recordAudioOnClickRelease()
        
    }
    @IBAction func deleteButton(sender: UIButton) {
        
        arrayOfFiles.removeAll()
     
        fileTableView.reloadData()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "\(userInfo)"
        self.soundFileTitle = "\(userInfo)"
        
        
        timer = NSTimer()
        waitTime = 1.500;
        
        let waveRect = CGRectMake(0, view.bounds.midY, view.bounds.width, 40.0)
        waveView = SCSiriWaveformView.init(frame: waveRect)
        view.addSubview(waveView)
        
        setUpRecorder()
        recorder.meteringEnabled = true
        recordAudioOnClick()
        
        recorder.updateMeters()
        startLevel = recorder.averagePowerForChannel(0)
        startTime()
    }
    
    
    func updateMeters()
    {
        
        var normalizedValue:Float = 0.0
        switch waveViewInputType{
        case SCSiriWaveformViewInputType.Recorder?:
            recorder.updateMeters()
            normalizedValue = normalizedPowerLevelFromDecibels(recorder.averagePowerForChannel(0))
            break
        case SCSiriWaveformViewInputType.Player?:
            player.updateMeters()
            normalizedValue = normalizedPowerLevelFromDecibels(player.averagePowerForChannel(0))
            break
        default:
            break
        }
        
        waveView.updateWithLevel(CGFloat(normalizedValue))
    }
    
    private func normalizedPowerLevelFromDecibels(decibels:Float) -> Float{
        if decibels < -40 {
            print(decibels)
        }
        if (decibels < -60.0 || decibels == 0.0) {
            return 0.0
        }
        return powf((powf(10.0, 0.05 * decibels) - powf(10.0, 0.05 * -60.0)) * (1.0 / (1.0 - powf(10.0, 0.05 * -60.0))), 1.0 / 2.0)
    }
    func updateProgress(){
        //updateMeters()
    }
    
    private func runMeterTimer(){
        
        meterTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "updateProgress", userInfo: nil, repeats: true)
    }
    
    func recordAudioOnClick(){
        
        print("Pressed")
        if !isRecording{
            isRecording = true
//            if soundFileURL != nil {
//                do{
//                    try NSFileManager.defaultManager().removeItemAtPath(soundFileURL.path!)
//                }catch let error as NSError{
//                    print(error)
//                }
//            }
            
       
            
            waveViewInputType = SCSiriWaveformViewInputType.Recorder
            setUpRecorder()
            
            do{
                try AVAudioSession.sharedInstance().setActive(true)
                recorder.record()
                runMeterTimer()
            }catch let error as NSError{
                print(error)
            }
        }
    }
    
    private func setUpRecorder(){
        
        getRecorderFileURLPath()
        
//        print(soundFileURL)
        let recorderSettings:[String:AnyObject] = [AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatMPEG4AAC), AVSampleRateKey : 44100.0 as NSNumber, AVNumberOfChannelsKey : 2 as NSNumber, AVEncoderAudioQualityKey : AVAudioQuality.High.rawValue as NSNumber,AVEncoderBitRateKey : 320000 as NSNumber]
        
        do {
            recorder = try AVAudioRecorder(URL: soundFileURL, settings: recorderSettings)
            recorderLimitTime != nil ? recorder.recordForDuration(recorderLimitTime!) : recorder.recordForDuration(18000)
            recorder.delegate = self
            recorder.meteringEnabled = true
            recorder.prepareToRecord()
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            
        }catch let error as NSError{
            print(error)
        }
    }
    
    func recordAudioOnClickRelease(){
        
        if isRecording{
            isRecording = false
        
            if(recorder.recording){
                recorder.stop()
            }
             stopRecord()

            meterTimer.invalidate()
            timer.invalidate()
            
            waveViewInputType = nil
            setUpPlayer()
            
        }
    }
    
    
    func cancelBarButtonOnClick(){
     
        
        if displayLink != nil{
            displayLink.invalidate()
        }
        
        if meterTimer != nil{
            meterTimer.invalidate()
        }
        
        waveView = nil
        toolBar = nil
        recorder = nil
        playBtn = nil
        stopBtn = nil
        player = nil
        
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.view.alpha = 0
            }) { (finished) -> Void in
                self.view.removeFromSuperview()
                self.removeFromParentViewController()
                self.dismissViewControllerAnimated(false,completion: nil)
        }
    }
    
    @IBAction func playRecord(){
        
        if !isPlaying && player != nil {
            isPlaying = true
            
            player.play()
            runMeterTimer()
        }
    }
    
    @IBAction func stopRecord(){
        isRecording = false
        
            }
    
    private func addFileToArray()
    {
        let f = AudioFile()
        if let fileName = fileName {
            f.title = fileName
            f.loadUrl = soundFileURL
            self.arrayOfFiles.append(f)
//            print(arrayOfFiles.count)
            self.fileTableView.reloadData()
        }

    }
    
    
    private func updateTimes()
    {
        if let currentLevel = endLevel
        {
            startLevel = currentLevel
        }
        
        print( "\(endLevel) :end  start: \(startLevel) \(isRecording) " )
        endLevel = recorder.averagePowerForChannel(0)
    }
    
    private func startTime()
    {
        timer = NSTimer.scheduledTimerWithTimeInterval(waitTime, target: self, selector: "checkSoundVolume", userInfo: nil, repeats: true)
        isRecording = true
        
    }
    
    func checkSoundVolume()
    {
        recorder.updateMeters()
        updateTimes()
        if((endLevel < -30 && startLevel < -30) || (endLevel >= -10 && startLevel >= -10)) && isRecording
        {
            print("Splitting audio")
            splitAudio()
            recorder.meteringEnabled = true
            recorder.updateMeters()
        }
        else if  endLevel < -110
        {
            setUpRecorder()
         
        }
    }
    
    
    ///Splits audio into chunks based on low sound level.
    ///stop recording -> file with timestamp
    ///start new file with name
    private func splitAudio() ->Void
    {
         recorder.stop()
//        do
//        {
//            let play = try AVAudioPlayer.init(contentsOfURL: soundFileURL)
//            if(play.duration < 4.0)
//            {
//                recorder.deleteRecording()
//            }
//            else
//            {
//                //Call to write
//                stopRecord()
//                addFileToArray()
//            }
//        }
//        catch
//        {
//          print("duration fail")
//        }

       setUpRecorder()
        do{
            try AVAudioSession.sharedInstance().setActive(true)
            recorder.record()
            runMeterTimer()
            startTime()
        }catch let error as NSError{
            print(error)
        }
        recorder.record()
    }
    func getCourtSoundURL() -> NSURL
    {
        
        
        let audioFilename = getDocumentsDirectory().stringByAppendingPathComponent("court audio-"+userInfo)
        let audioURL = NSURL(fileURLWithPath: audioFilename)
        
        return audioURL
    }
    
    func getDocumentsDirectory() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as [String]
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    private func getRecorderFileURLPath()  {
        
        let format = NSDateFormatter()
        format.dateFormat = "hh.mm.ssSSS"
        
        if let fileTitle = soundFileTitle {
            let currentFileName = "\(fileTitle)_\(format.stringFromDate(NSDate())).m4a"
            fileName = currentFileName
            let documentDirectory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
            soundFileURL = documentDirectory.URLByAppendingPathComponent(currentFileName)
            
        }else{
            
            let currentFileName = "\(format.stringFromDate(NSDate())).m4a"
            let documentDirectory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
            soundFileURL = documentDirectory.URLByAppendingPathComponent(currentFileName)
            fileName = currentFileName
            
        }
        
        //delete start?
        
    }
    
    
    private func setUpPlayer(){
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            player = try AVAudioPlayer(contentsOfURL: recorder.url)
            player.delegate = self
            
            player.prepareToPlay()
        }catch let error as NSError{
            print(error)
        }
    }
    
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        
//        self.stopRecord()
    }
    
    
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        
            let play = AVPlayer(URL: soundFileURL)
            let derp = play.currentItem
            let time = derp?.duration
            let erp = CMTimeGetSeconds(time!)
            if(erp < 4.0)
            {
                recorder.deleteRecording()
                isRecording = true
            }
            else
            {
                //Call to write
                stopRecord()
                addFileToArray()
            }
        
        isRecording = true
        self.recordAudioOnClickRelease()
        
    }
    
    //MARK: -TableView
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let a = arrayOfFiles[indexPath.row]
        
        let cell = tableView.dequeueReusableCellWithIdentifier("FileCell", forIndexPath: indexPath) as! FilesTableViewCell
        cell.fileNameLabel.text = a.title
        return cell
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrayOfFiles.count
    }

}
