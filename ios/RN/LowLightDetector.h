#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/// A class responsible for detecting low light conditions and image movement in camera frames.
/// It processes video sample buffers to compute brightness, exposure, and motion metrics.
@interface LowLightDetector : NSObject

/// Indicates whether the current scene is in low light conditions.
@property (nonatomic, assign) BOOL isLowLight;

/// Frame counter for skipping frames between checks.
@property (nonatomic, assign) NSInteger frameCount;

/// The current brightness value of the preview frame (0-255).
@property (nonatomic, assign) int previewBrightness;

/// The exposure time from EXIF metadata.
@property (nonatomic, assign) float previewExposure;

/// The calculated exposure reference value.
@property (nonatomic, assign) float previewExposureRef;

/// Array of ISO speed ratings from EXIF metadata.
@property (nonatomic, strong) NSArray *previewISO;

/// Initializes the LowLightDetector with default values.
/// @return An initialized instance.
- (instancetype)init;

/// Processes a camera frame sample buffer to update low light and movement states.
/// @param sampleBuffer The CMSampleBufferRef from camera output.
- (void)processFrame:(CMSampleBufferRef)sampleBuffer;

/// Checks if the exposure reference indicates low light.
/// @param exposure_ref The exposure reference value.
/// @return YES if too dark, NO otherwise.
- (BOOL)isTooDark:(double)exposure_ref;

/// Extracts EXIF metadata from a sample buffer.
/// @param sampleBuffer The sample buffer.
/// @return Dictionary containing EXIF data.
- (NSDictionary *)getExifMetadata:(CMSampleBufferRef)sampleBuffer;

/// Computes average brightness by sampling pixels.
/// @param pixelSpacing Step size for sampling.
/// @return Average brightness (0-255).
- (int)computeImageBrightness:(int)pixelSpacing;

/// Resets the detector's state and buffers.
- (void)reset;

@end