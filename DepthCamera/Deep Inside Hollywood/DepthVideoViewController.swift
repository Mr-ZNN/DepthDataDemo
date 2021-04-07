/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import AVFoundation
import Photos

class DepthVideoViewController: UIViewController {
  @IBOutlet weak var previewView: UIImageView!
  @IBOutlet weak var previewModeControl: UISegmentedControl!
  @IBOutlet weak var filterControl: UISegmentedControl!
  @IBOutlet weak var fileTypeControl: UISegmentedControl!
  @IBOutlet weak var depthSlider: UISlider!
  @IBOutlet weak var captruButton: UIButton!
  

  var sliderValue: CGFloat = 0.0
  var previewMode = PreviewMode.filtered
  var filter = FilterType.comic
  var fileType = FileType.photo
  
  let captureSession = AVCaptureSession()
  let videoDataOutput = AVCaptureVideoDataOutput()
  let depthDataOutput = AVCaptureDepthDataOutput()
  var outputSynchronizer: AVCaptureDataOutputSynchronizer?
  let dataOutputQueue = DispatchQueue(label: "video data queue",
                                      qos: .userInitiated,
                                      attributes: [],
                                      autoreleaseFrequency: .workItem)
  
  let background: CIImage! = CIImage(image: UIImage(named: "earth-rise")!)
  var depthMap: CIImage?
  var mask: CIImage?
  var scale: CGFloat = 0.0
  var depthFilters = DepthImageFilters()
  
  //拍摄视频相关
  private var videoWriter: AVAssetWriter?
  private var writerInput: AVAssetWriterInput?
  var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  var frameNumber: Int64 = 0
  private var depthDataBuffer: [CVPixelBuffer] = []
  private var isRecording = false

  override func viewDidLoad() {
    super.viewDidLoad()

    filterControl.isHidden = true
    depthSlider.isHidden = true

    previewMode = PreviewMode(rawValue: previewModeControl.selectedSegmentIndex) ?? .filtered
    filter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .comic
    sliderValue = CGFloat(depthSlider.value)
    //默认选中最后一个
    previewModeControl.selectedSegmentIndex = 3
    previewModeChanged(previewModeControl)
    previewModeControl.isHidden = true

    configureCaptureSession()

    captureSession.startRunning()
  }


}

// MARK: - Helper Methods
extension DepthVideoViewController {
  func configureCaptureSession() {
    guard let camera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .unspecified) else {
      fatalError("No depth video camera available")
    }

    captureSession.sessionPreset = .photo

    //add video input
    do {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      captureSession.addInput(cameraInput)
    } catch {
      fatalError(error.localizedDescription)
    }
    
    //add audio input
    do {
      let audioDevice = AVCaptureDevice.default(for: .audio)
      let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
      captureSession.addInput(audioDeviceInput)
    } catch {
      fatalError(error.localizedDescription)
    }
    
    //add videoDataOutput
    videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    captureSession.addOutput(videoDataOutput)
    let videoConnection = videoDataOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait
    
    //add depthDataOutput
    depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
    depthDataOutput.isFilteringEnabled = true
    captureSession.addOutput(depthDataOutput)
    let depthConnection = depthDataOutput.connection(with: .depthData)
    depthConnection?.videoOrientation = .portrait

    // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
    // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
//    outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
//    outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
    
    let outputRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    let videoRect = videoDataOutput
      .outputRectConverted(fromMetadataOutputRect: outputRect)
    let depthRect = depthDataOutput
      .outputRectConverted(fromMetadataOutputRect: outputRect)

    scale =
      max(videoRect.width, videoRect.height) /
      max(depthRect.width, depthRect.height)

    do {
      try camera.lockForConfiguration()

      if let format = camera.activeDepthDataFormat,
        let range = format.videoSupportedFrameRateRanges.first  {
        camera.activeVideoMinFrameDuration = range.minFrameDuration
      }

      camera.unlockForConfiguration()
    } catch {
      fatalError(error.localizedDescription)
    }
  }
}

// MARK: - Capture Video Data Delegate Methods
extension DepthVideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    let image = CIImage(cvPixelBuffer: pixelBuffer!)

    let previewImage: CIImage

    switch (previewMode, filter, mask) {
    case (.original, _, _):
      previewImage = image
    case (.depth, _, _):
      previewImage = depthMap ?? image
    case (.mask, _, let mask?):
      previewImage = mask
    case (.filtered, .comic, let mask?):
      previewImage = depthFilters.comic(image: image, mask: mask)
    case (.filtered, .greenScreen, let mask?):
      previewImage = depthFilters.greenScreen(image: image,
                                              background: background,
                                              mask: mask)
    case (.filtered, .blur, let mask?):
      previewImage = depthFilters.blur(image: image, mask: mask)
    case (.filtered, .crys, let mask?):
      previewImage = depthFilters.crystallize(image: image, mask: mask)
    case (.filtered, .color, let mask?):
      previewImage = depthFilters.color(image: image, mask: mask)
    case (.filtered, .haha, let mask?):
      previewImage = depthFilters.haha(image: image, mask: mask)
    case (.filtered, .rotate, let mask?):
      previewImage = depthFilters.rotate(image: image, mask: mask)
    case (.filtered, .edges, let mask?):
      previewImage = depthFilters.edges(image: image, mask: mask)
    default:
      previewImage = image
    }

    let displayImage = UIImage(ciImage: previewImage)
    DispatchQueue.main.async { [weak self] in
      self?.previewView.image = displayImage
    }
    
    
    //增加保存视频
    if isRecording {
      
      guard let newPixelBuffer = buffer(from: displayImage) else {
        print("PixelBuffer Error")
        return
      }
//      CVPixelBufferLockBaseAddress(newPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
//      let bufferWidth = CVPixelBufferGetWidth(newPixelBuffer)
//      let bufferHeight = CVPixelBufferGetHeight(newPixelBuffer)
//      let bytesPerRow = CVPixelBufferGetBytesPerRow(newPixelBuffer)
//      let baseAddress = CVPixelBufferGetBaseAddress(newPixelBuffer)
//
//      // Copy the pixel buffer
//      var pixelBufferCopy: CVPixelBuffer? = nil
//      _ = CVPixelBufferCreate(kCFAllocatorDefault, bufferWidth, bufferHeight, kCVPixelFormatType_DisparityFloat32, nil, &pixelBufferCopy);
//      if let pixelBufferCopy = pixelBufferCopy {
//        CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
//        let copyBaseAddress = CVPixelBufferGetBaseAddress(pixelBufferCopy)
//        memcpy(copyBaseAddress, baseAddress, bufferHeight * bytesPerRow)
//        CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
//
//        depthDataBuffer.append(pixelBufferCopy)
//        if !processVideo(sampleBuffer: sampleBuffer) {
//          print("Dropping frame")
//          let _ = depthDataBuffer.popLast()
//          frameNumber -= 1
//        }
//      }
//      CVPixelBufferUnlockBaseAddress(newPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
      
      depthDataBuffer.append(newPixelBuffer)
      if !processVideo(sampleBuffer: newPixelBuffer) {
        print("Dropping frame")
        let _ = depthDataBuffer.popLast()
        frameNumber -= 1
      }
    }
    
  }

}

// MARK: - Capture Video Data Delegate Methods
//extension DepthVideoViewController: AVCaptureDataOutputSynchronizerDelegate {
//  func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
//    guard isRecording else { return }
//
//    guard let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
//      return
//    }
//
//    guard !syncedVideoData.sampleBufferWasDropped else {
//      let droppedReason = syncedVideoData.droppedReason
//      switch droppedReason {
//      case .discontinuity:
//        print("discont")
//      case .lateData:
//        print("late")
//      case .outOfBuffers:
//        print("Out of buffers")
//      case .none:
//        print("none")
//      @unknown default:
//        print("Dropping sample buffer")
//      }
//      return
//    }
//
//    let videoSampleBuffer = syncedVideoData.sampleBuffer
//    guard let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData, !syncedDepthData.depthDataWasDropped else {
//      print("Dropped depth data")
//      return
//    }
//
//    let convertedDepthData = syncedDepthData.depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32).depthDataMap
//    convertedDepthData.normalize()
//
//    let pixelBuffer = convertedDepthData
//
//    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
//    let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
//    let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
//    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
//
//    // Copy the pixel buffer
//    var pixelBufferCopy: CVPixelBuffer? = nil
//    let status = CVPixelBufferCreate(kCFAllocatorDefault, bufferWidth, bufferHeight, kCVPixelFormatType_DisparityFloat32, nil, &pixelBufferCopy);
//    if let pixelBufferCopy = pixelBufferCopy {
//      CVPixelBufferLockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
//      let copyBaseAddress = CVPixelBufferGetBaseAddress(pixelBufferCopy)
//      memcpy(copyBaseAddress, baseAddress, bufferHeight * bytesPerRow)
//      CVPixelBufferUnlockBaseAddress(pixelBufferCopy, CVPixelBufferLockFlags(rawValue: 0))
//
//      depthDataBuffer.append(pixelBufferCopy)
//      if !processVideo(sampleBuffer: videoSampleBuffer) {
//        print("Dropping frame")
//        let _ = depthDataBuffer.popLast()
//        frameNumber -= 1
//      }
//    }
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
//  }
//}
// MARK: - Capture Depth Data Delegate Methods
extension DepthVideoViewController: AVCaptureDepthDataOutputDelegate {
  func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                       didOutput depthData: AVDepthData,
                       timestamp: CMTime,
                       connection: AVCaptureConnection) {
    guard previewMode != .original else {
      return
    }

    var convertedDepth: AVDepthData

    let depthDataType = kCVPixelFormatType_DisparityFloat32
    if depthData.depthDataType != depthDataType {
      convertedDepth = depthData.converting(toDepthDataType: depthDataType)
    } else {
      convertedDepth = depthData
    }

    let pixelBuffer = convertedDepth.depthDataMap
    pixelBuffer.clamp()

    let depthMap = CIImage(cvPixelBuffer: pixelBuffer)

    if previewMode == .mask || previewMode == .filtered {
      switch filter {
      case .comic:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      case .greenScreen:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale,
                                               isSharp: true)
      case .blur:
        mask = depthFilters.createBandPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      case .crys:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      case .color:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      case .haha:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      case .rotate:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      case .edges:
        mask = depthFilters.createHighPassMask(for: depthMap,
                                               withFocus: sliderValue,
                                               andScale: scale)
      }
      
    }

    DispatchQueue.main.async { [weak self] in
      self?.depthMap = depthMap
    }
  }
}

// MARK: - Slider Methods
extension DepthVideoViewController {
  @IBAction func sliderValueChanged(_ sender: UISlider) {
    sliderValue = CGFloat(depthSlider.value)
  }
}

// MARK: - Segmented Control Methods
extension DepthVideoViewController {
  @IBAction func previewModeChanged(_ sender: UISegmentedControl) {
    previewMode = PreviewMode(rawValue: previewModeControl.selectedSegmentIndex) ?? .filtered

    switch previewMode {
    case .mask, .filtered:
      filterControl.isHidden = false
      depthSlider.isHidden = false
    case .depth, .original:
      filterControl.isHidden = true
      depthSlider.isHidden = true
    }
  }

  @IBAction func filterTypeChanged(_ sender: UISegmentedControl) {
    filter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .comic
  }
  
  @IBAction func fileTypeChanged(_ sender: Any) {
    fileType = FileType(rawValue: fileTypeControl.selectedSegmentIndex) ?? .photo
  }
}
// MARK: - Button Methods
extension DepthVideoViewController {
  @IBAction func captrueButtonEvent(_ sender: Any) {
    
    if fileType == .photo {
      //保存图片到相册
      saveImageToAlbum(currentImage: self.previewView.image)
      //saveImageToDocuments(currentImage: self.previewView.image, persent: 0.5, imageName: "image.jpg")
    } else {
      //录制视频
      setRecording()
    }
  }
  
}

extension DepthVideoViewController {
  
  private func startRecording() {
    guard captureSession.isRunning else { return }
    
    let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    guard let videoFileUrl = paths.first?.appendingPathComponent("video.mov") else {
      print("Error")
      return
    }
    
    try? FileManager.default.removeItem(at: videoFileUrl)
    
    videoWriter = try? AVAssetWriter(outputURL: videoFileUrl, fileType: .mov)
    guard let videoWriter = videoWriter else {
      print("Error")
      return
    }
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
    writerInput.expectsMediaDataInRealTime = true
    videoWriter.add(writerInput)
    self.writerInput = writerInput
    
    pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes:
      [ kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)])
    
    if videoWriter.startWriting() {
      depthDataBuffer = []
      frameNumber = 0
      videoWriter.startSession(atSourceTime: CMTime.zero)
    }
  }
  
  private func stopRecording(writeCompletion: @escaping () -> Void) {
//    captureSession.stopRunning()
    writerInput?.markAsFinished()
    videoWriter?.finishWriting(completionHandler: writeCompletion)
  }
  
  private func setRecording() {
    if !isRecording {
      isRecording = true
      startRecording()
    } else {
      isRecording = false
      stopRecording(writeCompletion: { [weak self] in
        guard let `self` = self else { return }
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        if let videoFileUrl = paths.first?.appendingPathComponent("video.mov") {
           print(videoFileUrl)
            self.saveVideoToAlbum(videoUrl: videoFileUrl)
        }
      })
      print("count is : \(self.depthDataBuffer.count)")
    }
  }
  
//  fileprivate func processVideo(sampleBuffer: CMSampleBuffer) -> Bool {
//    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let writerInput = writerInput, writerInput.isReadyForMoreMediaData {
//      pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: CMTimeMake(value: frameNumber, timescale: 30))
//      frameNumber += 1
//      return true
//    }
//    return false
//  }
  
  fileprivate func processVideo(sampleBuffer: CVPixelBuffer?) -> Bool {
    if let imageBuffer = sampleBuffer {
      pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: CMTimeMake(value: frameNumber, timescale: 30))
      frameNumber += 1
      return true
    }
    return false
  }
}

// MARK: - Private Methods
extension DepthVideoViewController {
  //保存图片至沙盒
  private func saveImageToDocuments(currentImage: UIImage?, persent: CGFloat, imageName: String){
      guard let image = currentImage else {
          print("error: 图片为空")
          return
      }
      if let imageData = image.jpegData(compressionQuality: persent) as NSData? {
          let fullPath = NSHomeDirectory().appending("/Documents/").appending(imageName)
          imageData.write(toFile: fullPath, atomically: true)
          print("图片保存成功: fullPath=\(fullPath)")
      }
  }
  
  //保存图片至相册
  private func saveImageToAlbum(currentImage: UIImage?) {
    guard let image = currentImage else {
      print("图片不存在")
      return
    }
    guard let imageData = image.jpegData(compressionQuality: 0.5) as Data? else {
      print("图片转码失败")
      return
    }
    PHPhotoLibrary.requestAuthorization { (status) in
      if status == .authorized {
        PHPhotoLibrary.shared().performChanges {
          
          let creationRequest = PHAssetCreationRequest.forAsset()
          creationRequest.addResource(with: .photo, data: imageData, options: nil)
          
        } completionHandler: { (success, error) in
          if !success {
              print("不能保存照片到相册: \(String(describing: error))")
          } else {
            print("照片保存成功")
          }
        }
      }
    }
  }
  
  //保存视频至相册
  private func saveVideoToAlbum(videoUrl: URL?) {
    guard let url = videoUrl else {
      print("视频链接为nil")
      return
    }
    PHPhotoLibrary.requestAuthorization { (status) in
      if status == .authorized {
        PHPhotoLibrary.shared().performChanges {
          
          let creationRequest = PHAssetCreationRequest.forAsset()
          creationRequest.addResource(with: .video, fileURL: url, options: nil)
          
        } completionHandler: { (success, error) in
          if !success {
              print("不能保存视频到相册: \(String(describing: error))")
          } else {
            print("视频保存成功")
          }
        }
      }
    }
  }
  
  private func buffer(from image: UIImage) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer : CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard (status == kCVReturnSuccess) else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

    context?.translateBy(x: 0, y: image.size.height)
    context?.scaleBy(x: 1.0, y: -1.0)

    UIGraphicsPushContext(context!)
    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

    return pixelBuffer
  }
}
