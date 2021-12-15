//
//  ViewController.swift
//  QuestionExtractionHelper
//
//  Created by SASAKI Iori on 2021/12/15.
//

import UIKit
import Speech
import AVFoundation

class ViewController: UIViewController {
    
    enum MicRecognizeState {
        case stopping, listening
    }
    enum Language: String {
        case english = "en_US"
        case japanese = "ja_JP"
    }
    private var curRecordingState: MicRecognizeState = .stopping
    private var curLanguage: Language = .english
    
    private var recognizer: SFSpeechRecognizer!
    private var audioEngine: AVAudioEngine!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @IBOutlet weak var micStartButton: UIButton!
    @IBOutlet weak var allTextView: UITextView!
    @IBOutlet weak var curRecordingStateLabel: UILabel!
    @IBOutlet weak var languageSwitcher: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.audioEngine = AVAudioEngine()
        self.allTextView.text = ""
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // check privacy authorization of speech recognition
        SFSpeechRecognizer.requestAuthorization { (status) in
            DispatchQueue.main.sync {
                if status != SFSpeechRecognizerAuthorizationStatus.authorized {
                    self.micStartButton.isEnabled = false
                    self.allTextView.text = "Cannot start it because speech recognizer has not been permitted by user."
                }
            }
        }
    }
    
    @IBAction func switchCurLanguage(_ sender: UISegmentedControl) {
        let segmentIndex = sender.selectedSegmentIndex
        if segmentIndex==0 {
            self.curLanguage = .english
        } else if segmentIndex==1 {
            self.curLanguage = .japanese
        }
    }
    
}


//MARK: - button action

extension ViewController {
    @IBAction func didPushMicStartButton(_ sender: UIButton) {
        switch self.curRecordingState {
        case .listening:
            UIView.animate(withDuration: 0.2) {
                self.languageSwitcher.isEnabled = true
                self.curRecordingStateLabel.text = "stopping"
            }
            stopLiveRecognizing()
            self.curRecordingState = .stopping
        case .stopping:
            UIView.animate(withDuration: 0.2) {
                self.languageSwitcher.isEnabled = false
                self.curRecordingStateLabel.text = "listening"
            }
            try! startLiveRecognizing()
            self.curRecordingState = .listening
        }
    }
}


//MARK: - speech recognition

extension ViewController {
    private func startLiveRecognizing() throws {
        if let recognitionTask = self.recognitionTask {
            // under executing speech recognition task
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // generate request of speech recognition
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = self.recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = self.audioEngine.inputNode
        
        // setup mic input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { (buffer, time) in
            recognitionRequest.append(buffer)
        }
        self.audioEngine.prepare()
        try audioEngine.start()
        
        //
        //
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: self.curLanguage.rawValue))!
        
        self.recognitionTask = self.recognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            if let error = error {
                print("\(error)")
            } else {
                DispatchQueue.main.async {
                    self.allTextView.text = result?.bestTranscription.formattedString
                }
            }
        })
    }
    
    private func stopLiveRecognizing() {
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.recognitionRequest?.endAudio()
    }
}
