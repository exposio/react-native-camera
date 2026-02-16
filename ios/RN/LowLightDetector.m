#import "LowLightDetector.h"
#import <ImageIO/ImageIO.h>
#import <Accelerate/Accelerate.h>
#include <math.h>

static float const THRESHOLD_MOVEMENT_DEFAULT = 5.0;
static float const THRESHOLD_EXPOSURE = 0.05;
static NSInteger const SAMPLE_SIZE = 30;

@implementation LowLightDetector

/// Initializes the LowLightDetector with default values.
/// Sets all properties to their initial states and prepares the pixel buffer array.
- (instancetype)init {
    self = [super init];
    if (self) {
        self.isLowLight = NO;
        self.imageIsMoving = NO;
        self.listOfPixelBuffer = [NSMutableArray array];
        self.lastDiff = 0.0;
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
    NSLog(@"Processing frame with data length: %lu", (unsigned long)[imageData length]);
    if ([self.listOfPixelBuffer count] != 0 && [imageData length] != [[self.listOfPixelBuffer objectAtIndex:0] length]) {
        [self.listOfPixelBuffer removeAllObjects];
    }

    [self.listOfPixelBuffer addObject:imageData];

    if (self.listOfPixelBuffer.count >= SAMPLE_SIZE) {
        NSDictionary *exifMetadata = [self getExifMetadata:sampleBuffer];

        self.previewBrightness = [self computeImageBrightness:10];
        NSLog(@"Computed brightness: %d", self.previewBrightness);
        self.previewExposure = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifExposureTime] floatValue];
        self.previewISO = [NSArray arrayWithArray:[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifISOSpeedRatings]];
        NSLog(@"Exposure: %f, ISO: %@", self.previewExposure, self.previewISO);

        int coefficient = 1;
        if (self.previewBrightness >= (int)255 * 0.25) {
            coefficient = 0;
        }
        if (self.previewBrightness > (int)255 * 0.75) {
            coefficient = -1;
        }
        self.previewExposureRef = pow(2, log((double)[[self.previewISO objectAtIndex:0] intValue] / 100) / log((double)2) + coefficient) * self.previewExposure;
        NSLog(@"Calculated exposure reference: %f", self.previewExposureRef);

        BOOL isLowLight = [self isTooDark:self.previewExposureRef];
        NSLog(@"Is low light: %@", isLowLight ? @"YES" : @"NO");
        if (isLowLight) {
            if (self.isLowLight == NO) {
                self.isLowLight = isLowLight;
                NSLog(@"Low light condition started");
            }
            self.lastDiff = [self computeImageMovement:10];
            self.imageIsMoving = [self isMoving:self.lastDiff];
            NSLog(@"Movement diff: %f, Is moving: %@", self.lastDiff, self.imageIsMoving ? @"YES" : @"NO");
        } else {
            if (self.isLowLight) {
                self.isLowLight = isLowLight;
                NSLog(@"Low light condition ended");
                // Event emission handled by manager
            }
            self.lastDiff = 0.0;
            self.imageIsMoving = NO;
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

/// Checks if the movement difference indicates image motion.
/// @param difference The computed movement difference.
/// @return YES if moving, NO otherwise.
- (BOOL)isMoving:(float)difference {
    return (difference > THRESHOLD_MOVEMENT_DEFAULT);
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

/// Computes the average brightness of the latest frame by sampling pixels.
/// @param pixelSpacing The step size for pixel sampling (e.g., 10 for every 10th pixel).
/// @return The average brightness value (0-255).
- (int)computeImageBrightness:(int)pixelSpacing {
    NSData *data = [self.listOfPixelBuffer objectAtIndex:(SAMPLE_SIZE - 1)];
    UInt8 *pixels = (UInt8 *)[data bytes];
    unsigned long length = [data length];
    int luminance = 0;
    int n = 0;
    for (int i = 0; i < length; i += pixelSpacing) {
        luminance += pixels[i];
        n++;
    }
    return (int)roundf(luminance / n);
}

/// Computes the movement in the image by calculating standard deviation across buffered frames.
/// @param pixelSpacing The step size for pixel sampling.
/// @return The average standard deviation indicating movement level.
- (float)computeImageMovement:(int)pixelSpacing {
    NSMutableArray *frames = [[NSMutableArray alloc] initWithArray:self.listOfPixelBuffer copyItems:YES];
    int numberOfFrames = (int)frames.count;
    long imageSize = [[frames objectAtIndex:0] length];
    float standardDeviation = 0.0;
    UInt8 *pixels;
    for (int i = 0; i < imageSize; i += pixelSpacing) {
        NSMutableArray *row = [[NSMutableArray alloc] init];
        for (int j = 0; j < numberOfFrames; j++) {
            pixels = (UInt8 *)[[frames objectAtIndex:j] bytes];
            [row addObject:@(pixels[i])];
        }
        NSExpression *expression = [NSExpression expressionForFunction:@"stddev:" arguments:@[[NSExpression expressionForConstantValue:row]]];
        NSNumber *stdDev = [expression expressionValueWithObject:nil context:nil];
        standardDeviation += [stdDev floatValue];
    }
    return (float)standardDeviation / (imageSize / pixelSpacing);
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
    self.imageIsMoving = NO;
    [self.listOfPixelBuffer removeAllObjects];
    self.lastDiff = 0.0;
    self.previewBrightness = 0;
    self.previewExposure = 0.0;
    self.previewExposureRef = 0.0;
    self.previewISO = nil;
}

@end