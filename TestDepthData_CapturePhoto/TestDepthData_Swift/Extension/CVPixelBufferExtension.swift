//
//  CVPixelBufferExtension.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

import AVFoundation
import UIKit

extension CVPixelBuffer {
  
  func normalize() {
    
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)
    
    CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)
    
    var minPixel: Float = 1.0
    var maxPixel: Float = 0.0
    
    for y in 0 ..< height {
      for x in 0 ..< width {
        let pixel = floatBuffer[y * width + x]
        minPixel = min(pixel, minPixel)
        maxPixel = max(pixel, maxPixel)
      }
    }
    
    let range = maxPixel - minPixel
    
    for y in 0 ..< height {
      for x in 0 ..< width {
        let pixel = floatBuffer[y * width + x]
        floatBuffer[y * width + x] = (pixel - minPixel) / range
      }
    }
    
    CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
  }
  
  func printDebugInfo() {
    
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
    let totalBytes = CVPixelBufferGetDataSize(self)
    
    print("Depth Map Info: \(width)x\(height)")
    print(" Bytes per Row: \(bytesPerRow)")
    print("   Total Bytes: \(totalBytes)")
  }
  
  func convertToDisparity32() -> CVPixelBuffer? {
    
    let width = CVPixelBufferGetWidth(self)
    let height = CVPixelBufferGetHeight(self)

    var dispartyPixelBuffer: CVPixelBuffer?
    
    let _ = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_DisparityFloat32, nil, &dispartyPixelBuffer)
    
    guard let outputPixelBuffer = dispartyPixelBuffer else {
      return nil
    }
    
    CVPixelBufferLockBaseAddress(outputPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 1))
    
    let outputBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(outputPixelBuffer), to: UnsafeMutablePointer<Float>.self)
    let inputBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<UInt8>.self)

    for y in 0 ..< height {
      for x in 0 ..< width {
        let pixel = inputBuffer[y * width + x]
        outputBuffer[y * width + x] = (Float(pixel) / Float(UInt8.max))
      }
    }

    CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 1))
    CVPixelBufferUnlockBaseAddress(outputPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

    return dispartyPixelBuffer
  }
}

