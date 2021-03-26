//
//  UIImageExtension.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

import UIKit

extension UIImage {
  
  convenience init?(ciImage: CIImage?) {
    
    guard let ciImage = ciImage else {
      return nil
    }
    
    self.init(ciImage: ciImage)
  }
}
