//
//  RNCameraFocusSquare.m
//  abseil
//
//  Created by Jonathan Gilbert on 2021-10-01.
//

#import "RNCameraFocusSquare.h"
#import <QuartzCore/QuartzCore.h>

const float squareLength = 80.0f;
@implementation RNCameraFocusSquare

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code

        [self setBackgroundColor:[UIColor clearColor]];
        [self.layer setBorderWidth:2.0];
        [self.layer setCornerRadius:4.0];
        [self.layer setBorderColor:[UIColor whiteColor].CGColor];

        CABasicAnimation* selectionAnimation = [CABasicAnimation
                                                animationWithKeyPath:@"borderColor"];
        selectionAnimation.toValue = (id)[UIColor blueColor].CGColor;
        selectionAnimation.repeatCount = 8;
        [self.layer addAnimation:selectionAnimation
                          forKey:@"selectionAnimation"];

    }
    return self;
}

@end
