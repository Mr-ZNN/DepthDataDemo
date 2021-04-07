//
//  StringExtension.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/30.
//

import Foundation


extension String{
    /// check string cellection is whiteSpace
    var isBlank : Bool{
        return allSatisfy({$0.isWhitespace})
    }
}

extension Optional where Wrapped == String{
    var isBlank : Bool{
        return self?.isBlank ?? true
    }
}
