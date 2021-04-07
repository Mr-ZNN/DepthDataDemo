//
//  DepthImageFilters.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

import UIKit
import Foundation

enum MaskParams {
    static let slope: CGFloat = 4.0//斜率
    static let width: CGFloat = 0.1//宽度
}

class DepthImageFilters {
    
    var context: CIContext
    
    init(context: CIContext) {
        self.context = context
    }
    
    init() {
        context = CIContext()
    }
    
    func createMask(for depthImage: CIImage, withFocus focus: CGFloat, andScale scale: CGFloat) -> CIImage {
        
        let s1 = MaskParams.slope
        let s2 = -MaskParams.slope
        let filterWidth =  2 / MaskParams.slope + MaskParams.width
        let b1 = -s1 * (focus - filterWidth / 2)
        let b2 = -s2 * (focus + filterWidth / 2)
        
        let mask0 = depthImage
          .applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: s1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: s1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: s1, w: 0),
            "inputBiasVector": CIVector(x: b1, y: b1, z: b1, w: 0)])
          .applyingFilter("CIColorClamp")
        
        let mask1 = depthImage
          .applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: s2, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: s2, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: s2, w: 0),
            "inputBiasVector": CIVector(x: b2, y: b2, z: b2, w: 0)])
          .applyingFilter("CIColorClamp")
        
        let combinedMask = mask0.applyingFilter("CIDarkenBlendMode", parameters: ["inputBackgroundImage" : mask1])

        let mask = combinedMask.applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": scale])
                
        return mask
      }
      
    func spotlightHighlight(image: CIImage, mask: CIImage, orientation: UIImage.Orientation = .up) -> UIImage? {
        
        let output = image.applyingFilter("CIBlendWithMask", parameters: ["inputMaskImage": mask])
        
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
          return nil
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
      }

    func colorHighlight(image: CIImage, mask: CIImage, orientation: UIImage.Orientation = .up) -> UIImage? {
        //老照片滤镜
        //let greyscale = image.applyingFilter("CIPhotoEffectTransfer")
        //棕色滤镜
        //let greyscale = image.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 0.8])
        //颜色滤镜
        let greyscale = image.applyingFilter("CIColorMonochrome", parameters: ["inputColor": CIColor(color: .red), "inputIntensity": 0.8])
        
        //let maskFilter = mask.applyingFilter("CIColorMonochrome", parameters: ["inputColor": CIColor(color: .yellow), "inputIntensity": 0.8])
        //let maskFilter = mask.applyingFilter("CIPhotoEffectMono")
        
        let output = image.applyingFilter("CIBlendWithMask", parameters: ["inputBackgroundImage" : greyscale, "inputMaskImage": mask])
        
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
          return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
      }
      
      func blur(image: CIImage, mask: CIImage, orientation: UIImage.Orientation = .up) -> UIImage? {
        
        let invertedMask = mask.applyingFilter("CIColorInvert")
        let output = image.applyingFilter("CIMaskedVariableBlur", parameters: ["inputMask" : invertedMask, "inputRadius": 15.0])
        
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
          return nil
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
      }
    
    func blackWhite(image: CIImage, mask: CIImage, orientation: UIImage.Orientation = .up) -> UIImage? {
        //黑白滤镜
        let greyscale = image.applyingFilter("CIPhotoEffectMono")
        
        let output = image.applyingFilter("CIBlendWithMask", parameters: ["inputBackgroundImage" : greyscale, "inputMaskImage": mask])
        
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
          return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
      }
}
