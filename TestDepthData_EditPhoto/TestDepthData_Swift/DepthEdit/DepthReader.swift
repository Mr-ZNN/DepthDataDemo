//
//  DepthReader.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

#if !IOS_SIMULATOR
import AVFoundation

struct DepthReader {
  
  var name: String
  var ext: String
  
  /// 获取图片深度数据
  /// - Returns: 深度数据缓冲
  func depthDataMap() -> CVPixelBuffer? {
    
    // Create a CFURL for the image in the Bundle
    guard let fileURL = Bundle.main.url(forResource: name, withExtension: ext) as CFURL? else {
      return nil
    }
    
    // Create a CGImageSource
    guard let source = CGImageSourceCreateWithURL(fileURL, nil) else {
      return nil
    }
        
    guard let auxDataInfo = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDisparity) as? [AnyHashable : Any] else {
      return nil
    }
    
    // This is the star of the show!
    var depthData: AVDepthData
    
    do {
      // Get the depth data from the auxiliary data info
      depthData = try AVDepthData(fromDictionaryRepresentation: auxDataInfo)
      
    } catch {
      return nil
    }
    
    // Make sure the depth data is the type we want
    if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
      depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    }
    
    return depthData.depthDataMap
  }
}
#endif
