//
//  DepthReaderSimulatorHack.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

#if IOS_SIMULATOR
import AVFoundation
import UIKit

struct DepthReader {
  
  var name: String
  var ext: String
  
  func depthDataMap() -> CVPixelBuffer? {
    
    // Create a CFURL for the image in the Bundle
    guard let fileURL = Bundle.main.url(forResource: name, withExtension: ext) as CFURL? else {
      return nil
    }
    
    // Create a CGImageSource
    guard let source = CGImageSourceCreateWithURL(fileURL, nil) else {
      return nil
    }
    
    guard let cgImage = CGImageSourceCreateImageAtIndex(source, 1, nil) else {
      return nil
    }
    
    let depthDataMap = cgImage.pixelBuffer()?.convertToDisparity32()
    depthDataMap?.normalize()
    
    return depthDataMap
  }
}
#endif
