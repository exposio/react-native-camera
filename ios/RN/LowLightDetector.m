#import "LowLightDetector.h"
#import <ImageIO/ImageIO.h>
#import <Accelerate/Accelerate.h>
#include <math.h>

// static float const THRESHOLD_MOVEMENT_DEFAULT = 5.0; // Removed
static float const THRESHOLD_EXPOSURE = 0.05;
static NSInteger const SAMPLE_SIZE = 10;

@implementation LowLightDetector

/// Initializes the LowLightDetector with default values.
/// Sets all properties to their initial states and prepares the pixel buffer array.
- (instancetype)init {
    self = [super init];
    if (self) {
        self.isLowLight = NO;
        self.listOfPixelBuffer = [NSMutableArray array];
        self.previewBrightness = 0;
        self.previewExposure = 0.0;
        self.previewExposureRef = 0.0;
        self.previewISO = nil;
    }
    return self;
}

/// Processes a camera frame sample buffer to detect low light and movement.
/// Buffers frames, computes brightness and exposure, and updates low light state.
/// @param sampleBuffer The CMSampleBufferRef from the camera output.
- (void)processFrame:(CMSampleBufferRef)sampleBuffer {
    NSData *imageData = [self nsDataFromSampleBuffer:sampleBuffer];
    if ([self.listOfPixelBuffer count] != 0 && [imageData length] != [[self.listOfPixelBuffer objectAtIndex:0] length]) {
        [self.listOfPixelBuffer removeAllObjects];
    }

    [self.listOfPixelBuffer addObject:imageData];

    if (self.listOfPixelBuffer.count >= SAMPLE_SIZE) {
        NSDictionary *exifMetadata = [self getExifMetadata:sampleBuffer];

        self.previewBrightness = [self computeImageBrightness:10];
        self.previewExposure = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifExposureTime] floatValue];
        self.previewISO = [NSArray arrayWithArray:[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifISOSpeedRatings]];

        int coefficient = 1;
        if (self.previewBrightness >= (int)255 * 0.25) {
            coefficient = 0;
        }
        if (self.previewBrightness > (int)255 * 0.75) {
            coefficient = -1;
        }
        self.previewExposureRef = pow(2, log((double)[[self.previewISO objectAtIndex:0] intValue] / 100) / log((double)2) + coefficient) * self.previewExposure;

        BOOL isLowLight = [self isTooDark:self.previewExposureRef];
        if (isLowLight) {
            if (self.isLowLight == NO) {
                self.isLowLight = isLowLight;
            }
        } else {
            if (self.isLowLight) {
                self.isLowLight = isLowLight;
                // Event emission handled by manager
            }
        }

        [self.listOfPixelBuffer removeAllObjects];
    }
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

/// Computes the average brightness of the latest frame using vDSP for efficiency.
/// @param pixelSpacing The step size for pixel sampling (e.g., 10 for every 10th pixel).
/// @return The average brightness value (0-255).
- (int)computeImageBrightness:(int)pixelSpacing {
    NSData *data = [self.listOfPixelBuffer objectAtIndex:(SAMPLE_SIZE - 1)];
    UInt8 *pixels = (UInt8 *)[data bytes];
    unsigned long length = [data length];
    long count = (length + pixelSpacing - 1) / pixelSpacing;

    float *floatBuf = (float *)malloc(count * sizeof(float));
    for (long i = 0, idx = 0; idx < length; i++, idx += pixelSpacing) {
        floatBuf[i] = (float)pixels[idx];
    }
    float mean = 0;
    vDSP_meanv(floatBuf, 1, &mean, count);
    free(floatBuf);
    return (int)roundf(mean);
}

/// Converts a CMSampleBufferRef to NSData containing the Y-plane pixel data.
/// @param sampleBuffer The sample buffer from camera output.
/// @return NSData with grayscale pixel data.
- (NSData *)nsDataFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    size_t bytesPerRow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    size_t height0 = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
    void *srcBuff0 = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    NSData *yData = [[NSData alloc] initWithBytes:srcBuff0 length:bytesPerRow0 * height0];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return yData;
}

/// Resets the detector's state and clears all buffers.
/// Useful for restarting low light detection.
- (void)reset {
    self.isLowLight = NO;
    [self.listOfPixelBuffer removeAllObjects];
    self.previewBrightness = 0;
    self.previewExposure = 0.0;
    self.previewExposureRef = 0.0;
    self.previewISO = nil;
}

@end