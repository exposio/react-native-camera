#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class RCTCameraManager;

@interface RCTCamera : UIView

- (id)initWithManager:(RCTCameraManager*)manager bridge:(RCTBridge *)bridge;
- (AVCaptureVideoOrientation)getVideoOrientation;

@property (nonatomic, strong) RCTCameraFocusSquare *camFocus;
@end
