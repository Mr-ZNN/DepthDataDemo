//
//  DepthReader.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

#if !IOS_SIMULATOR
import AVFoundation

struct DepthReader {
    
    var imageData: Data?
    
    /// 获取图片深度数据
    /// - Returns: 深度数据缓冲
    func depthDataMap() -> CVPixelBuffer? {
        
        guard let data = (imageData as CFData?) else {
            return nil
        }
        // Create a CGImageSource
        guard let source = CGImageSourceCreateWithData(data, nil) else {
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
