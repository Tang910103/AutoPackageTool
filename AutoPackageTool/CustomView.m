//
//  CustomView.m
//  AutoPackageTool
//
//  Created by Tang杰 on 2018/11/26.
//  Copyright © 2018年 Tang杰. All rights reserved.
//

#import "CustomView.h"
#import "MBProgressHUD.h"

@interface CustomView ()<MBProgressHUDDelegate>
@property (nonatomic, strong) MBProgressHUD *HUD;

@end

@implementation CustomView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _HUD = [[MBProgressHUD alloc] initWithView:self];
        [self addSubview:_HUD];
        _HUD.dimBackground = YES;
        _HUD.delegate = self;
    }
    return self;
}
- (void)setFrame:(NSRect)frame
{
    [super setFrame:frame];
    self.HUD.frame = self.bounds;
}
- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
    
    if (!hidden) {
        [_HUD show:YES];
    } else {
        [_HUD hide:YES];
    }
}
- (void)otherMouseDown:(NSEvent *)event
{
    
}
- (void)mouseDown:(NSEvent *)event
{
    
}
- (void)rightMouseDown:(NSEvent *)event
{
    
}

@end
