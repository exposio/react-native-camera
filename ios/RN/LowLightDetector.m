#import "LowLightDetector.h"
#import <ImageIO/ImageIO.h>
#import <Accelerate/Accelerate.h>
#include <math.h>

static float const THRESHOLD_EXPOSURE = 0.05;
static NSInteger const FRAME_INTERVAL = 30;

@implementation LowLightDetector

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isLowLight = NO;
        self.frameCount = 0;
        self.previewBrightness = 0;
        self.previewExposure = 0.0;
        self.previewExposureRef = 0.0;
        self.previewISO = nil;
    }
    return self;
}

/// Processes a camera frame.
/// @param sampleBuffer The CMSampleBufferRef from camera output.
- (void)processFrame:(CMSampleBufferRef)sampleBuffer {
    self.frameCount++;
    
    if (self.frameCount < FRAME_INTERVAL) {
        return;
    }
    self.frameCount = 0;
    
    self.previewBrightness = [self computeImageBrightness:sampleBuffer pixelSpacing:10];
    
    NSDictionary *exifMetadata = [self getExifMetadata:sampleBuffer];
    self.previewExposure = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifExposureTime] floatValue];
    self.previewISO = [NSArray arrayWithArray:[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifISOSpeedRatings]];
    
    int coefficient = 1;
    if (self.previewBrightness >= (int)(255 * 0.25)) {
        coefficient = 0;
    }
    if (self.previewBrightness > (int)(255 * 0.75)) {
        coefficient = -1;
    }
    self.previewExposureRef = pow(2, log((double)[[self.previewISO objectAtIndex:0] intValue] / 100) / log((double)2) + coefficient) * self.previewExposure;
    
    self.isLowLight = [self isTooDark:self.previewExposureRef];
}

/// Checks if the exposure reference indicates low light conditions.
/// @param exposure_ref The calculated exposure reference value.
/// @return YES if too dark, NO otherwise.
- (BOOL)isTooDark:(double)exposure_ref {
    return (exposure_ref > THRESHOLD_EXPOSURE);
}

/// Extracts EXIF metadata from a camera sample buffer.
/// @param sampleBuffer The CMSampleBufferRef containing metadata.
/// @return A dictionary with EXIF data.
- (NSDictionary *)getExifMetadata:(CMSampleBufferRef)sampleBuffer {
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    return [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
}

/// Computes the average brightness of the given frame by sampling pixels.
/// @param sampleBuffer The CMSampleBufferRef from camera output.
/// @param pixelSpacing The step size for pixel sampling (e.g., 10 for every 10th pixel).
/// @return The average brightness value (0-255).
- (int)computeImageBrightness:(CMSampleBufferRef)sampleBuffer pixelSpacing:(int)pixelSpacing {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    size_t height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
    UInt8 *pixels = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    unsigned long length = bytesPerRow * height;
    int luminance = 0;
    int n = 0;
    for (int i = 0; i < length; i += pixelSpacing) {
        luminance += pixels[i];
        n++;
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    return (int)roundf((float)luminance / (float)n);
}

/// Resets the detector's state and clears all buffers.
/// Useful for restarting low light detection.
- (void)reset {
    self.isLowLight = NO;
    self.frameCount = 0;
    self.previewBrightness = 0;
    self.previewExposure = 0.0;
    self.previewExposureRef = 0.0;
    self.previewISO = nil;
}

@end