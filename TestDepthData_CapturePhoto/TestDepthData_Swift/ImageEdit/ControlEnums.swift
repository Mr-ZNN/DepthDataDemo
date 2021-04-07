//
//  ControlEnums.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

import Foundation

enum ImageModel: Int {
    case original = 0
    case depth
    case mask
    case filtered
}

enum FilterType: Int {
    case spotlight = 0
    case color
    case blur
    case blackWhite
}
