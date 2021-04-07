//
//  CIImageExtension.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

import UIKit

extension CIImage {
  
  convenience init?(image: UIImage?) {
    
    guard let image = image else {
      return nil
    }
    
    self.init(image: image)
  }
  
  convenience init?(cvPixelBuffer: CVPixelBuffer?) {
    
    guard let cvPixelBuffer = cvPixelBuffer else {
      return nil
    }
    
    self.init(cvPixelBuffer: cvPixelBuffer)
  }
  
  convenience init?(cgImage: CGImage?) {
    
    guard let cgImage = cgImage else {
      return nil
    }
    
    self.init(cgImage: cgImage)
  }
}
