#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/// A class responsible for detecting low light conditions and image movement in camera frames.
/// It processes video sample buffers to compute brightness, exposure, and motion metrics.
@interface LowLightDetector : NSObject

/// Indicates whether the current scene is in low light conditions.
@property (nonatomic, assign) BOOL isLowLight;

/// Indicates whether the image is moving based on frame differences.
@property (nonatomic, assign) BOOL imageIsMoving;

/// Array holding pixel data from recent camera frames for analysis.
@property (nonatomic, strong) NSMutableArray *listOfPixelBuffer;

/// The last computed movement difference value.
@property (nonatomic, assign) float lastDiff;

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

/// Checks if the movement difference indicates motion.
/// @param difference The movement difference value.
/// @return YES if moving, NO otherwise.
- (BOOL)isMoving:(float)difference;

/// Extracts EXIF metadata from a sample buffer.
/// @param sampleBuffer The sample buffer.
/// @return Dictionary containing EXIF data.
- (NSDictionary *)getExifMetadata:(CMSampleBufferRef)sampleBuffer;

/// Computes average brightness by sampling pixels.
/// @param pixelSpacing Step size for sampling.
/// @return Average brightness (0-255).
- (int)computeImageBrightness:(int)pixelSpacing;

/// Computes movement by calculating standard deviation across frames.
/// @param pixelSpacing Step size for sampling.
/// @return Average standard deviation.
- (float)computeImageMovement:(int)pixelSpacing;

/// Converts sample buffer to pixel data.
/// @param sampleBuffer The sample buffer.
/// @return NSData with Y-plane pixel data.
- (NSData *)nsDataFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/// Resets the detector's state and buffers.
- (void)reset;

@end