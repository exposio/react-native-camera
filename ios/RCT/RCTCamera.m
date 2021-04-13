#import <React/RCTBridge.h>
#import "RCTCamera.h"
#import "RCTCameraManager.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>

#import <React/UIView+React.h>

#import <AVFoundation/AVFoundation.h>

@interface RCTCamera ()

@property (nonatomic, weak) RCTCameraManager *manager;
@property (nonatomic, weak) RCTBridge *bridge;

@end

@implementation RCTCamera
{
  BOOL _multipleTouches;
  BOOL _onFocusChanged;
  BOOL _defaultOnFocusComponent;
  BOOL _onZoomChanged;
  BOOL _previousIdleTimerDisabled;
}

- (void)setOnFocusChanged:(BOOL)enabled
{
  if (_onFocusChanged != enabled) {
    _onFocusChanged = enabled;
  }
}

- (void)setDefaultOnFocusComponent:(BOOL)enabled
{
  if (_defaultOnFocusComponent != enabled) {
    _defaultOnFocusComponent = enabled;
  }
}

- (void)setOnZoomChanged:(BOOL)enabled
{
  if (_onZoomChanged != enabled) {
    _onZoomChanged = enabled;
  }
}

- (id)initWithManager:(RCTCameraManager*)manager bridge:(RCTBridge *)bridge
{
  if ((self = [super init])) {
    self.manager = manager;
    self.bridge = bridge;
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchToZoomRecognizer:)];
    [self addGestureRecognizer:pinchGesture];
    [self.manager initializeCaptureSessionInput:AVMediaTypeVideo];
    [self.manager startSession];
    _multipleTouches = NO;
    _onFocusChanged = NO;
    _defaultOnFocusComponent = YES;
    _onZoomChanged = NO;
    _previousIdleTimerDisabled = [UIApplication sharedApplication].idleTimerDisabled;
    [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification  object:nil];
    [self updateOrientation];
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  AVCaptureVideoOrientation orientation = [self getVideoOrientation];
    
  // We always use a 4/3 preset
  float aspectRatio = 4.0/3.0;
  float width = self.bounds.size.height * aspectRatio;

  UIEdgeInsets notchInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);

  if (@available(iOS 11.0, *)) {
    notchInsets = self.safeAreaInsets;
  }

  float paddingLeft = 0;
  float paddingTop = 0;
  float previewWidth = 0;
  float previewHeight = 0;

  if (orientation == AVCaptureVideoOrientationLandscapeRight) {
    previewWidth = width;
    previewHeight = self.bounds.size.height;
    paddingLeft = notchInsets.left + self.bounds.size.width - width;

    if (width / self.bounds.size.width < 0.8f) {
      paddingLeft = notchInsets.left + roundf((self.bounds.size.width - width) / 2);
    }
  } else if (orientation == AVCaptureVideoOrientationLandscapeLeft) {
    previewWidth = width;
    previewHeight = self.bounds.size.height;

    if (width / self.bounds.size.width < 0.8f) {
      paddingLeft = roundf((self.bounds.size.width - width - notchInsets.right) / 2);
    }
  } else {
    previewWidth = self.bounds.size.width;
    previewHeight = self.bounds.size.width * aspectRatio;
    paddingTop = (self.bounds.size.height - previewHeight);
  }

  self.manager.previewLayer.frame = CGRectMake(paddingLeft, paddingTop, previewWidth, previewHeight);

  // DEBUG colors
  // [self setBackgroundColor:UIColor.redColor];
  // self.manager.previewLayer.backgroundColor = UIColor.blueColor.CGColor;

  [self.layer insertSublayer:self.manager.previewLayer atIndex:0];
    
  if ([self.manager.cameraEventEmitter hasListener]) {
    NSDictionary *dimensions = @{
      @"top": @(self.manager.previewLayer.frame.origin.y),
      @"left": @(self.manager.previewLayer.frame.origin.x),
      @"width": @(self.manager.previewLayer.frame.size.width),
      @"height": @(self.manager.previewLayer.frame.size.height)
    };
    [self.manager.cameraEventEmitter sendOnDimensionChange:dimensions];
  }
}

- (void)insertReactSubview:(UIView *)view atIndex:(NSInteger)atIndex
{
  [self insertSubview:view atIndex:atIndex + 1];
  return;
}

- (void)removeReactSubview:(UIView *)subview
{
  [subview removeFromSuperview];
  return;
}

- (void)removeFromSuperview
{
  [super removeFromSuperview];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
  [UIApplication sharedApplication].idleTimerDisabled = _previousIdleTimerDisabled;
  [self.manager stopSession];
}

- (AVCaptureVideoOrientation)getVideoOrientation
{
  UIDeviceOrientation currentOrientation = [UIDevice currentDevice].orientation;

  switch (currentOrientation) {
    case UIDeviceOrientationFaceUp:
    case UIDeviceOrientationFaceDown:
    case UIDeviceOrientationPortraitUpsideDown:
      return self.manager.previewLayer.connection.videoOrientation;

    case UIDeviceOrientationLandscapeLeft:
      return AVCaptureVideoOrientationLandscapeRight;

    case UIDeviceOrientationLandscapeRight:
      return AVCaptureVideoOrientationLandscapeLeft;

    default:
      return AVCaptureVideoOrientationPortrait;
  }
}

- (void)orientationChanged:(NSNotification *)notification {
    [self updateOrientation];
}

-(void)updateOrientation {
    if (self.manager.previewLayer.connection.isVideoOrientationSupported) {
      AVCaptureVideoOrientation orientation = [self getVideoOrientation];

      if (orientation != self.manager.previewLayer.connection.videoOrientation) {
        self.manager.previewLayer.connection.videoOrientation = orientation;
        [self setNeedsLayout];
      }
    }
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Update the touch state.
  if ([[event touchesForView:self] count] > 1) {
    _multipleTouches = YES;
  }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (!_onFocusChanged) return;

  BOOL allTouchesEnded = ([touches count] == [[event touchesForView:self] count]);

  // Do not conflict with zooming and etc.
  if (allTouchesEnded && !_multipleTouches) {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchPoint = [touch locationInView:touch.view];
    // Focus camera on this point
    [self.manager focusAtThePoint:touchPoint];
  }

  if (allTouchesEnded) {
    _multipleTouches = NO;
  }
}


-(void) handlePinchToZoomRecognizer:(UIPinchGestureRecognizer*)pinchRecognizer {
  if (!_onZoomChanged) return;

  if (pinchRecognizer.state == UIGestureRecognizerStateChanged) {
    [self.manager zoom:pinchRecognizer.velocity reactTag:self.reactTag];
  }
}

- (void)changePreviewOrientation:(NSInteger)orientation
{
    dispatch_async(self.manager.sessionQueue, ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self.manager.previewLayer.connection.isVideoOrientationSupported) {
            self.manager.previewLayer.connection.videoOrientation = orientation;
        }
      });
    });
}

@end
