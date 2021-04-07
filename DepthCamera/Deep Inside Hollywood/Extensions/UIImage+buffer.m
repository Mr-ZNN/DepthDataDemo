/// Copyright (c) 2021 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

#import "UIImage+buffer.h"

@implementation UIImage (buffer)
- (CVPixelBufferRef)pixelBuffer{
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                           [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                           nil];

  CVPixelBufferRef pxbuffer = NULL;

  CGImageRef imageRef = self.CGImage;
  CGFloat frameWidth = CGImageGetWidth(imageRef);
  CGFloat frameHeight = CGImageGetHeight(imageRef);

  CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        frameWidth,
                                        frameHeight,
                                        kCVPixelFormatType_32ARGB,
                                        (__bridge CFDictionaryRef) options,
                                        &pxbuffer);

  NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

  CVPixelBufferLockBaseAddress(pxbuffer, 0);
  void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
  NSParameterAssert(pxdata != NULL);

  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

  CGContextRef context = CGBitmapContextCreate(pxdata,
                                               frameWidth,
                                               frameHeight,
                                               8,
                                               CVPixelBufferGetBytesPerRow(pxbuffer),
                                               rgbColorSpace,
                                               (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
  NSParameterAssert(context);
  CGContextConcatCTM(context, CGAffineTransformIdentity);
  CGContextDrawImage(context, CGRectMake(0,
                                         0,
                                         frameWidth,
                                         frameHeight),
                     imageRef);
  CGColorSpaceRelease(rgbColorSpace);
  CGContextRelease(context);

  CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

  return pxbuffer;

}

- (CVPixelBufferRef)pixelBuffer2
{
  CGImageRef imageRef = self.CGImage;
  
    CVPixelBufferRef pxbuffer = NULL;
    NSCParameterAssert(NULL != imageRef);
    size_t originalWidth = CGImageGetWidth(imageRef);
    size_t originalHeight = CGImageGetHeight(imageRef);
    
    NSMutableData *imageData = [NSMutableData dataWithLength:originalWidth*originalHeight*4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate([imageData mutableBytes], originalWidth, originalHeight, 8, 4*originalWidth, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(cgContext, CGRectMake(0, 0, originalWidth, originalHeight), imageRef);
    CGContextRelease(cgContext);
    CGImageRelease(imageRef);
    unsigned char *pImageData = (unsigned char *)[imageData bytes];
    
    
    CFDictionaryRef empty;
    empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL,
                               0,
                               &kCFTypeDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks);
    
    CFMutableDictionaryRef m_pPixelBufferAttribs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                      3,
                                                      &kCFTypeDictionaryKeyCallBacks,
                                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(m_pPixelBufferAttribs, kCVPixelBufferIOSurfacePropertiesKey, empty);
    CFDictionarySetValue(m_pPixelBufferAttribs, kCVPixelBufferOpenGLCompatibilityKey, empty);
    CFDictionarySetValue(m_pPixelBufferAttribs, kCVPixelBufferCGBitmapContextCompatibilityKey, empty);
    
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, originalWidth, originalHeight, kCVPixelFormatType_32BGRA, pImageData, originalWidth * 4, NULL, NULL, m_pPixelBufferAttribs, &pxbuffer);
    CFRelease(empty);
    CFRelease(m_pPixelBufferAttribs);
    
    
    return pxbuffer;
}
@end
