//
//  DepthImageViewController.swift
//  TestDepthData_Swift
//
//  Created by Davetech on 2021/3/24.
//

import UIKit
import AVFoundation

class DepthImageViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageModeControl: UISegmentedControl!
    @IBOutlet weak var filterControl: UISegmentedControl!
    @IBOutlet weak var depthSlider: UISlider!
    
    /// 原图
    var origImage: UIImage?
    /// 深度数据图
    var depthDataMapImage: UIImage?
    /// 过滤图
    var filterImage: CIImage?
    /// 图片数组
    var bundledJPGs = [String]()
    /// 当前选择的图片索引
    var current = 0
    /// 上下文
    let context = CIContext()
    
    /// 滤镜示例对象
    var depthFilters: DepthImageFilters?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        depthFilters = DepthImageFilters(context: context)
        //获取本地图片资源数组
        bundledJPGs = getAvailableImages()
        //加载当前的图片资源
        loadCurrent(image: bundledJPGs[current], withExtension: "jpg")
    }
    

}

// MARK: Depth Data Methods
extension DepthImageViewController {
  
}

// MARK: - Helper Methods
extension DepthImageViewController {
  
  func getAvailableImages() -> [String] {
    var availableImages = [String]()
    let base = "test"
    var name = base + "00"
    var num = 0 {
      didSet {
        name = base + String(format: "%02d", num)
      }
    }
    while Bundle.main.url(forResource: name, withExtension: "jpg") != nil {
      availableImages.append(name)
      num += 1
    }
    
    return availableImages
  }
    
    /// 加载当前的图片资源
    /// - Parameters:
    ///   - name: 图片名称
    ///   - ext: 扩展名
  func loadCurrent(image name: String, withExtension ext: String) {

    let depthReader = DepthReader(name: name, ext: ext)
    
    //从图片读取深度数据
    let depthDataMap: CVPixelBuffer? = depthReader.depthDataMap()
    
    if (depthDataMap == nil) {
        print("该图片没有深度数据！")
        return
    }
    
    //然后使用提供的CVPixelBuffer扩展来标准化深度数据。
    //这可以确保所有像素都在0.0和1.0之间，其中0.0是最远的像素，1.0是最近的像素。
    depthDataMap?.normalize()
    
    //将深度数据转换为CIImage，然后转换为UIImage
    let ciImage = CIImage(cvPixelBuffer: depthDataMap)
    depthDataMapImage = UIImage(ciImage: ciImage)
    
    //创建原始未修改的图片
    origImage = UIImage(named: "\(name).\(ext)")
    filterImage = CIImage(image: origImage)

    //设置分段控制器为原始图
    imageModeControl.selectedSegmentIndex = ImageModel.original.rawValue
    
    //更新图片视图
    updateImageView()
  }
  
  func updateImageView() {
    
    depthSlider.isHidden = true
    filterControl.isHidden = true
    imageView.image = nil

    let selectedImageMode = ImageModel(rawValue: imageModeControl.selectedSegmentIndex) ?? .original
    switch selectedImageMode {
    case .original:
      //原图
      imageView.image = origImage
    case .depth:
      //深度图
      #if IOS_SIMULATOR
        guard let orientation = origImage?.imageOrientation,
          let ciImage = depthDataMapImage?.ciImage,
          let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        imageView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
      #else
        imageView.image = depthDataMapImage
      #endif
    case .mask:
      // Mask
      depthSlider.isHidden = false

      guard let depthImage = depthDataMapImage?.ciImage else {
        return
      }

      let maxToDim = max((origImage?.size.width ?? 1.0), (origImage?.size.height ?? 1.0))
      let maxFromDim = max((depthDataMapImage?.size.width ?? 1.0), (depthDataMapImage?.size.height ?? 1.0))
      
      let scale = maxToDim / maxFromDim
      
      print("\(depthSlider.value)")
      guard let mask = depthFilters?.createMask(for: depthImage, withFocus: CGFloat(depthSlider.value), andScale: scale) else {
        return
      }
      
      guard let cgImage = context.createCGImage(mask, from: mask.extent),
        let origImage = origImage else {
          return
      }
      
      imageView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: origImage.imageOrientation)

    case .filtered:
      // Filtered
      depthSlider.isHidden = false
      filterControl.isHidden = false

      guard let depthImage = depthDataMapImage?.ciImage else {
        return
      }
      
      let maxToDim = max((origImage?.size.width ?? 1.0), (origImage?.size.height ?? 1.0))
      let maxFromDim = max((depthDataMapImage?.size.width ?? 1.0), (depthDataMapImage?.size.height ?? 1.0))
      
      let scale = maxToDim / maxFromDim

      print("\(depthSlider.value)")
      guard let mask = depthFilters?.createMask(for: depthImage, withFocus: CGFloat(depthSlider.value), andScale: scale),
        let filterImage = filterImage,
        let orientation = origImage?.imageOrientation else {
          return
      }
      
      let finalImage: UIImage?
      
      let selectedFilter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .spotlight
      
      switch selectedFilter {
      case .spotlight:
        finalImage = depthFilters?.spotlightHighlight(image: filterImage, mask: mask, orientation: orientation)
      case .color:
        finalImage = depthFilters?.colorHighlight(image: filterImage, mask: mask, orientation: orientation)
      case .blur:
        finalImage = depthFilters?.blur(image: filterImage, mask: mask, orientation: orientation)
      }
      
      imageView.image = finalImage
    }
  }
}

// MARK: Slider Methods
extension DepthImageViewController {
  @IBAction func sliderValueChanged(_ sender: UISlider) {
    updateImageView()
  }
}

// MARK: Segmented Control Methods
extension DepthImageViewController {
  @IBAction func segementedControlValueChanged(_ sender: UISegmentedControl) {
    updateImageView()
  }
  
  @IBAction func filterTypeChanged(_ sender: UISegmentedControl) {
    updateImageView()
  }
}

// MARK: Gesture Recognizor Methods
extension DepthImageViewController {
    @IBAction func imageTapped(_ sender: UITapGestureRecognizer) {
      current = (current + 1) % bundledJPGs.count
      loadCurrent(image: bundledJPGs[current], withExtension: "jpg")
    }
}
