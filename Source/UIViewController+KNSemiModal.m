//
//  KNSemiModalViewController.m
//  KNSemiModalViewController
//
//  Created by Kent Nguyen on 2/5/12.
//  Copyright (c) 2012 Kent Nguyen. All rights reserved.
//

#import "UIViewController+KNSemiModal.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "NSObject+YMOptionsAndDefaults.h"

const struct KNSemiModalOptionKeys KNSemiModalOptionKeys = {
	.traverseParentHierarchy = @"KNSemiModalOptionTraverseParentHierarchy",
	.pushParentBack = @"KNSemiModalOptionPushParentBack",
	.animationDuration = @"KNSemiModalOptionAnimationDuration",
	.parentAlpha = @"KNSemiModalOptionParentAlpha",
	.shadowOpacity = @"KNSemiModalOptionShadowOpacity",
	.transitionStyle = @"KNSemiModalTransitionStyle",
    .disableCancel = @"KNSemiModalOptionDisableCancel",
};

#define kSemiModalTransitionOptions @"kn_semiModalTransitionOptions"
#define kSemiModalTransitionDefaults @"kn_semiModalTransitionDefaults"
#define kSemiModalViewController @"kn_semiModalSemiModalViewController"
#define kSemiModalDismissBlock @"kn_semiModalDismissBlock"
#define kSemiModalOverlayTag 10001
#define kSemiModalScreenshotTag 10002
#define kSemiModalModalViewTag 10003
#define kSemiModalDismissButtonTag 10004

@interface UIViewController (KNSemiModalInternal)
-(UIView*)parentTarget;
-(CAAnimationGroup*)animationGroupForward:(BOOL)_forward;
@end

@implementation UIViewController (KNSemiModalInternal)


-(UIViewController*)kn_parentTargetViewController {
	UIViewController * target = self;
	if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.traverseParentHierarchy] boolValue]) {
		// cover UINav & UITabbar as well
		while (target.parentViewController != nil) {
			target = target.parentViewController;
		}
	}
	return target;
}
-(UIView*)parentTarget {
    return [self kn_parentTargetViewController].view;
}

#pragma mark Options and defaults

-(void)kn_registerTransitionDefaults {
	NSDictionary *defaults = @{
                            KNSemiModalOptionKeys.animationDuration : @(0.5),
                            KNSemiModalOptionKeys.parentAlpha : @(0.5),
                            KNSemiModalOptionKeys.pushParentBack : @(YES),
                            KNSemiModalOptionKeys.shadowOpacity : @(0.8),
                            KNSemiModalOptionKeys.disableCancel : @(NO),
                            };
	objc_setAssociatedObject(self, kSemiModalTransitionDefaults, defaults, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(void)kn_registerDefaultsAndOptions:(NSDictionary*)options {
	[self ym_registerOptions:options defaults:@{
     KNSemiModalOptionKeys.traverseParentHierarchy : @YES,
     KNSemiModalOptionKeys.pushParentBack : @YES,
     KNSemiModalOptionKeys.animationDuration : @0.35,
     KNSemiModalOptionKeys.parentAlpha : @0.5,
     KNSemiModalOptionKeys.shadowOpacity : @0.8,
     KNSemiModalOptionKeys.transitionStyle : @(KNSemiModalTransitionStyleSlideUp),
	 }];
}

#pragma mark Push-back animation group

-(CAAnimationGroup*)animationGroupForward:(BOOL)_forward {
    // Create animation keys, forwards and backwards
    CATransform3D t1 = CATransform3DIdentity;
    t1.m34 = 1.0/-900;
    t1 = CATransform3DScale(t1, 0.95, 0.95, 1);
    t1 = CATransform3DRotate(t1, 15.0f*M_PI/180.0f, 1, 0, 0);
    
    CATransform3D t2 = CATransform3DIdentity;
    t2.m34 = t1.m34;
    t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08, 0);
    t2 = CATransform3DScale(t2, 0.8, 0.8, 1);
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation.toValue = [NSValue valueWithCATransform3D:t1];
	CFTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
    animation.duration = duration/2;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    
    CABasicAnimation *animation2 = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation2.toValue = [NSValue valueWithCATransform3D:(_forward?t2:CATransform3DIdentity)];
    animation2.beginTime = animation.duration;
    animation2.duration = animation.duration;
    animation2.fillMode = kCAFillModeForwards;
    animation2.removedOnCompletion = NO;
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    [group setDuration:animation.duration*2];
    [group setAnimations:[NSArray arrayWithObjects:animation,animation2, nil]];
    return group;
}

-(void)moveWithPercentToFinish:(float)percent {
    NSLog(@"move with percent to finish: %f", percent);
    UIImageView *ss = (UIImageView*)objc_getAssociatedObject(self, @"ss");
    if (percent < .5 && percent > 0) {
        //first transform
        CATransform3D t1 = CATransform3DIdentity;
        t1.m34 = 1.0/-900;
        
        t1 = CATransform3DScale(t1, 1-(.05*percent*2), 1-(.05*percent*2), 1);
        t1 = CATransform3DRotate(t1, 15.0f*percent*2*M_PI/180.0f, 1, 0, 0);
        
        
        
        ss.layer.transform = t1;
    } else if (percent<1 && percent > 0){
        //second transfrom
        CATransform3D t2 = CATransform3DIdentity;
        t2.m34 = 1.0/-900;
        t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08*(percent-.5)*2, 0);
        t2 = CATransform3DScale(t2, .95-(.15*(percent-.5)*2), .95-(.15*(percent-.5)*2), 1);
        t2 = CATransform3DRotate(t2, (15.0f-(15.0f*(percent-.5)*2))*M_PI/180.0f, 1, 0, 0);
        
        ss.layer.transform = t2;
    }
    if (percent<1 && percent > 0) {
        UIView *view = (UIView*)objc_getAssociatedObject(self, @"view");
        CGAffineTransform translate = CGAffineTransformMakeTranslation(0, -1 * percent * view.frame.size.height);
        view.transform = translate;
        
        ss.alpha = 1 - ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue] * percent);
        
    }
    
    
}

- (void)dismissSemiModalViewByPanningWithPercent:(float)percent {
    NSLog(@"move with percent to finish: %f", percent);
    UIView * target = [self parentTarget];
    UIImageView * ss = (UIImageView*)objc_getAssociatedObject(self, @"ss");
    if (percent < .5 && percent > 0) {
        //first transform
        CATransform3D t1 = CATransform3DIdentity;
        t1.m34 = 1.0/-900;
        
        t1 = CATransform3DScale(t1, 1-(.05*percent*2), 1-(.05*percent*2), 1);
        t1 = CATransform3DRotate(t1, 15.0f*percent*2*M_PI/180.0f, 1, 0, 0);
        
        ss.layer.transform = t1;
    } else if (percent<1 && percent > 0){
        //second transfrom
        CATransform3D t2 = CATransform3DIdentity;
        t2.m34 = 1.0/-900;
        t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08*(percent-.5)*2, 0);
        t2 = CATransform3DScale(t2, .95-(.15*(percent-.5)*2), .95-(.15*(percent-.5)*2), 1);
        t2 = CATransform3DRotate(t2, (15.0f-(15.0f*(percent-.5)*2))*M_PI/180.0f, 1, 0, 0);
        
        ss.layer.transform = t2;
    }
    if (percent<1 && percent > 0) {
        UIView *view = (UIView*)objc_getAssociatedObject(self, @"view");
        CGAffineTransform translate = CGAffineTransformMakeTranslation(0, -1 * percent * view.frame.size.height);
        view.transform = translate;
        
        ss.alpha = 1 - ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue] * percent);
        
    }
    
    
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (flag) {
        [self setFinalTransform];
    }
}
- (void)setFinalTransform {
    NSLog(@"set final transform");
    UIImageView *ss = objc_getAssociatedObject(self, @"ss");
    
    
    CATransform3D t2 = CATransform3DIdentity;
    t2.m34 = 1.0/-900;
    t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08, 0);
    t2 = CATransform3DScale(t2, 0.8, 0.8, 1);
    t2 = CATransform3DRotate(t2, 15.0f*M_PI*180.0f, 1, 0, 0);
    
    
    ss.layer.transform = t2;
    [ss.layer removeAllAnimations];
    
}

- (void)animateRestOfWayUpWithPercent:(float)percent {
    UIImageView *ss = objc_getAssociatedObject(self, @"ss");
    
    
    CATransform3D t1 = CATransform3DIdentity;
    t1.m34 = 1.0/-900;
    t1 = CATransform3DScale(t1, 0.95, 0.95, 1);
    t1 = CATransform3DRotate(t1, 15.0f*M_PI/180.0f, 1, 0, 0);
    
    CATransform3D t2 = CATransform3DIdentity;
    t2.m34 = 1.0/-900;
    t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08, 0);
    t2 = CATransform3DScale(t2, 0.8, 0.8, 1);
    
    CFTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
    
    CABasicAnimation *animation2 = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation2.toValue = [NSValue valueWithCATransform3D:(t2)];
    animation2.fillMode = kCAFillModeForwards;
    animation2.removedOnCompletion = NO;
    if (percent < .5) {
        //has to do both animations
        float timeToSpendOnFirstAnimation = duration*(.5-percent);
        
        animation2.beginTime = timeToSpendOnFirstAnimation;
        animation2.duration = duration - timeToSpendOnFirstAnimation;
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
        animation.toValue = [NSValue valueWithCATransform3D:t1];
        animation.duration = timeToSpendOnFirstAnimation;
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = NO;
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        
        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.fillMode = kCAFillModeForwards;
        group.removedOnCompletion = NO;
        [group setDuration:duration];
        [group setAnimations:[NSArray arrayWithObjects:animation,animation2, nil]];
        
        [ss.layer addAnimation:group forKey:@"transform"];
    } else {
        //only has to do second animation
        animation2.duration = duration;
        
        [ss.layer addAnimation:animation2 forKey:@"transform"];
    }
    
    
    KNTransitionCompletionBlock completion = objc_getAssociatedObject(self, @"completion");
    
    UIView *view = objc_getAssociatedObject(self, @"view");
    [UIView animateWithDuration:duration animations:^{
        view.transform = CGAffineTransformMakeTranslation(0, -1 * view.frame.size.height);
        ss.alpha = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue];
    }completion:^(BOOL finished){
        [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidShowNotification object:self];
        [self setFinalTransform];
        
        if (completion) {
            completion();
        }
    }];
}

- (void)animateRestOfWayDownWithPercent:(float)percent {
    UIImageView *ss = objc_getAssociatedObject(self, @"ss");
    
    CFTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
    
    CATransform3D t1 = CATransform3DIdentity;
    t1.m34 = 1.0/-900;
    t1 = CATransform3DScale(t1, 0.95, 0.95, 1);
    t1 = CATransform3DRotate(t1, 15.0f*M_PI/180.0f, 1, 0, 0);
    
    CATransform3D t2 = CATransform3DIdentity;
    t2.m34 = t1.m34;
    t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08, 0);
    t2 = CATransform3DScale(t2, 0.8, 0.8, 1);
    
    
    
    if (percent > .5) {
        //has to do both animations
        float timeToSpendOnFirstAnimation = duration * (percent - .5);
        
        NSLog(@"time to spend on first animation: %f out of: %f", timeToSpendOnFirstAnimation, duration);
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
        animation.toValue = [NSValue valueWithCATransform3D:t1];
        animation.duration = timeToSpendOnFirstAnimation;
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = NO;
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        
        CABasicAnimation *animation2 = [CABasicAnimation animationWithKeyPath:@"transform"];
        animation2.toValue = [NSValue valueWithCATransform3D:(CATransform3DIdentity)];
        animation2.beginTime = timeToSpendOnFirstAnimation;
        animation2.duration = duration - timeToSpendOnFirstAnimation;
        animation2.fillMode = kCAFillModeForwards;
        animation2.removedOnCompletion = NO;
        
        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.fillMode = kCAFillModeForwards;
        group.removedOnCompletion = NO;
        [group setDuration:duration];
        [group setAnimations:[NSArray arrayWithObjects:animation,animation2, nil]];
        
        [ss.layer addAnimation:group forKey:@"transform"];
        
    } else {
        //only has to do first animation(second?)
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
        animation.toValue = [NSValue valueWithCATransform3D:(CATransform3DIdentity)];
        animation.duration = duration;
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = NO;
        [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        
        [ss.layer addAnimation:animation forKey:@"transform"];
    }
    
    UIView *view = (UIView*)objc_getAssociatedObject(self, @"view");
    
    [UIView animateWithDuration:duration animations:^{
        view.transform = CGAffineTransformMakeTranslation(0, 0);
        ss.alpha = 1;
    }completion:^(BOOL finished){
        UIView * target = [self parentTarget];
        UIView * modal = [target.subviews objectAtIndex:target.subviews.count-1];
        UIView * overlay = [target.subviews objectAtIndex:target.subviews.count-2];
        UIViewController *vc = objc_getAssociatedObject(self, kSemiModalViewController);
        [overlay removeFromSuperview];
        [modal removeFromSuperview];
        [vc removeFromParentViewController];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidHideNotification object:self];
    }];
}

-(void)selfPan:(UIPanGestureRecognizer*)panGesture {
    UIView *view = (UIView*)objc_getAssociatedObject(self, @"view");
    
    CGPoint translation = [panGesture translationInView:self.view];
    CGPoint velocity = [panGesture velocityInView:self.view];
    float percent = (1-(translation.y/view.frame.size.height));
    if (panGesture.state == UIGestureRecognizerStateEnded || panGesture.state == UIGestureRecognizerStateCancelled) {
        if (velocity.y < -400) {
            [self finishMovingSemiViewControllerUpWithPercent:percent];
        } else if (velocity.y > 400) {
            [self finishMovingSemiViewControllerDownWithPercent:percent];
        } else {
            if (percent < .5) {
                //go down
                [self finishMovingSemiViewControllerDownWithPercent:percent];
            } else {
                //go up
                [self finishMovingSemiViewControllerUpWithPercent:percent];
            }
        }
        
        
    } else {
        
        [self dismissSemiModalViewByPanningWithPercent:percent];
    }
}

-(void)kn_interfaceOrientationDidChange:(NSNotification*)notification {
	UIView *overlay = [[self parentTarget] viewWithTag:kSemiModalOverlayTag];
	[self kn_addOrUpdateParentScreenshotInView:overlay];
}

-(UIImageView*)kn_addOrUpdateParentScreenshotInView:(UIView*)screenshotContainer {
	UIView *target = [self parentTarget];
	UIView *semiView = [target viewWithTag:kSemiModalModalViewTag];
	
	screenshotContainer.hidden = YES; // screenshot without the overlay!
	semiView.hidden = YES;
	UIGraphicsBeginImageContextWithOptions(target.bounds.size, YES, [[UIScreen mainScreen] scale]);
    [target.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	screenshotContainer.hidden = NO;
	semiView.hidden = NO;
	
	UIImageView* screenshot = (id) [screenshotContainer viewWithTag:kSemiModalScreenshotTag];
	if (screenshot) {
		screenshot.image = image;
	}
	else {
		screenshot = [[UIImageView alloc] initWithImage:image];
		screenshot.tag = kSemiModalScreenshotTag;
		screenshot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[screenshotContainer addSubview:screenshot];
	}
	return screenshot;
}

-(UIImageView*)snapshotWithPredefinedView:(UIView*)predefined container:(UIView*)screenshotContainer {
    UIView *target = predefined;
	UIView *semiView = [target viewWithTag:kSemiModalModalViewTag];
	
	screenshotContainer.hidden = YES; // screenshot without the overlay!
	semiView.hidden = YES;
	UIGraphicsBeginImageContextWithOptions(target.bounds.size, YES, [[UIScreen mainScreen] scale]);
    [target.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	screenshotContainer.hidden = NO;
	semiView.hidden = NO;
	
	UIImageView* screenshot = (id) [screenshotContainer viewWithTag:kSemiModalScreenshotTag];
	if (screenshot) {
		screenshot.image = image;
	}
	else {
		screenshot = [[UIImageView alloc] initWithImage:image];
		screenshot.tag = kSemiModalScreenshotTag;
		screenshot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[screenshotContainer addSubview:screenshot];
	}
	return screenshot;
}

@end

@implementation UIViewController (KNSemiModal)

- (void)moveSemiViewWithPercentToFinish:(float)percent {
    [self moveWithPercentToFinish:percent];
}

- (void)beginMoveSemiViewController:(UIViewController *)vc withPredefinedSnapshotView:(UIView *)snap {
    [self presentSemiViewControllerForMoving:vc withPredefinedSnapshotView:snap withOptions:nil completion:nil dismissBlock:nil];
}

-(void)presentSemiViewController:(UIViewController*)vc {
	[self presentSemiViewController:vc withOptions:nil completion:nil dismissBlock:nil];
}
-(void)presentSemiViewController:(UIViewController*)vc
					 withOptions:(NSDictionary*)options {
    [self presentSemiViewController:vc withOptions:options completion:nil dismissBlock:nil];
}
-(void)presentSemiViewController:(UIViewController *)vc withPredefinedSnapshotView:(UIView *)snap {
    [self presentSemiViewController:vc withPreDefinedSnapshot:snap withOptions:nil completion:nil dismissBlock:nil];
}
-(void)presentSemiViewController:(UIViewController *)vc withPredefinedImage:(UIImage *)image {
    [self presentSemiViewController:vc withPreDefinedImage:image withOptions:nil completion:nil dismissBlock:nil];
}
-(void)presentSemiViewController:(UIViewController*)vc
					 withOptions:(NSDictionary*)options
					  completion:(KNTransitionCompletionBlock)completion
					dismissBlock:(KNTransitionCompletionBlock)dismissBlock {
    [self kn_registerDefaultsAndOptions:options];
	UIViewController *targetParentVC = [self kn_parentTargetViewController];
	// implement view controller containment for the semi-modal view controller
	[targetParentVC addChildViewController:vc];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:YES animated:YES]; // iOS 6
	}
	objc_setAssociatedObject(self, kSemiModalViewController, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, kSemiModalDismissBlock, dismissBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
	[self presentSemiView:vc.view withOptions:options completion:^{
		[vc didMoveToParentViewController:targetParentVC];
		if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
			[vc endAppearanceTransition]; // iOS 6
		}
		if (completion) {
			completion();
		}
	}];
}

-(void)presentSemiViewController:(UIViewController*)vc
          withPreDefinedSnapshot:(UIView*)snap
					 withOptions:(NSDictionary*)options
					  completion:(KNTransitionCompletionBlock)completion
					dismissBlock:(KNTransitionCompletionBlock)dismissBlock {
    [self kn_registerDefaultsAndOptions:options];
	UIViewController *targetParentVC = [self kn_parentTargetViewController];
	// implement view controller containment for the semi-modal view controller
	[targetParentVC addChildViewController:vc];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:YES animated:YES]; // iOS 6
	}
	objc_setAssociatedObject(self, kSemiModalViewController, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, kSemiModalDismissBlock, dismissBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
	[self presentSemiView:vc.view predefinedSnapshot:(snap) withOptions:options completion:^{
		[vc didMoveToParentViewController:targetParentVC];
		if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
			[vc endAppearanceTransition]; // iOS 6
		}
        
		if (completion) {
			completion();
		}
	}];
}

-(void)presentSemiViewController:(UIViewController*)vc
             withPreDefinedImage:(UIImage*)image
					 withOptions:(NSDictionary*)options
					  completion:(KNTransitionCompletionBlock)completion
					dismissBlock:(KNTransitionCompletionBlock)dismissBlock {
    [self kn_registerDefaultsAndOptions:options];
	UIViewController *targetParentVC = [self kn_parentTargetViewController];
	// implement view controller containment for the semi-modal view controller
	[targetParentVC addChildViewController:vc];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:YES animated:YES]; // iOS 6
	}
	objc_setAssociatedObject(self, kSemiModalViewController, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, kSemiModalDismissBlock, dismissBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
	[self presentSemiView:vc.view predefinedImage:(image) withOptions:options completion:^{
		[vc didMoveToParentViewController:targetParentVC];
		if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
			[vc endAppearanceTransition]; // iOS 6
		}
		if (completion) {
			completion();
		}
	}];
}

- (void)presentSemiViewControllerForMoving:(UIViewController*)vc
                withPredefinedSnapshotView:(UIView*)snap
                               withOptions:(NSDictionary*)options
                                completion:(KNTransitionCompletionBlock)completion
                              dismissBlock:(KNTransitionCompletionBlock)dismissBlock {
    
    [self kn_registerDefaultsAndOptions:options];
	UIViewController *targetParentVC = [self kn_parentTargetViewController];
	// implement view controller containment for the semi-modal view controller
	[targetParentVC addChildViewController:vc];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:YES animated:YES]; // iOS 6
	}
	objc_setAssociatedObject(self, kSemiModalViewController, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, kSemiModalDismissBlock, dismissBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
	[self presentSemiViewForMoving:vc.view withPredefinedSnapshotView:snap withOptions:options completion:^{
		[vc didMoveToParentViewController:targetParentVC];
		if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
			[vc endAppearanceTransition]; // iOS 6
		}
		if (completion) {
			completion();
		}
	}];
    
}

-(void)presentSemiView:(UIView*)view {
	[self presentSemiView:view withOptions:nil completion:nil];
}
-(void)presentSemiView:(UIView*)view withOptions:(NSDictionary*)options {
	[self presentSemiView:view withOptions:options completion:nil];
}
-(void)presentSemiView:(UIView*)view
		   withOptions:(NSDictionary*)options
			completion:(KNTransitionCompletionBlock)completion {
	[self kn_registerDefaultsAndOptions:options]; // re-registering is OK
	UIView * target = [self parentTarget];
	
    if (![target.subviews containsObject:view]) {
        // Register for orientation changes, so we can update the presenting controller screenshot
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(kn_interfaceOrientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        NSUInteger transitionStyle = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionStyle] unsignedIntegerValue];
        
        // Calulate all frames
        CGFloat semiViewHeight = view.frame.size.height;
        CGRect vf = target.bounds;
        CGRect semiViewFrame = CGRectMake(0, vf.size.height-semiViewHeight, vf.size.width, semiViewHeight);
        CGRect overlayFrame = CGRectMake(0, 0, vf.size.width, vf.size.height-semiViewHeight);
        
        // Add semi overlay
        UIView * overlay = [[UIView alloc] initWithFrame:target.bounds];
        overlay.backgroundColor = [UIColor blackColor];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.tag = kSemiModalOverlayTag;
        
        // Take screenshot and scale
        UIImageView *ss = [self kn_addOrUpdateParentScreenshotInView:overlay];
        objc_setAssociatedObject(self, @"ss", ss, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [target addSubview:overlay];
        
        objc_setAssociatedObject(self, @"ss", ss, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @"view", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Dismiss button (if allow)
        if(![[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.disableCancel] boolValue]) {
            // Don't use UITapGestureRecognizer to avoid complex handling
            UIButton * dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [dismissButton addTarget:self action:@selector(dismissSemiModalView) forControlEvents:UIControlEventTouchUpInside];
            dismissButton.backgroundColor = [UIColor clearColor];
            dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            dismissButton.frame = overlayFrame;
            dismissButton.tag = kSemiModalDismissButtonTag;
            [overlay addSubview:dismissButton];
        }
        
        // Begin overlay animation
		if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue]) {
			[ss.layer addAnimation:[self animationGroupForward:YES] forKey:@"pushedBackAnimation"];
		}
		NSTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
        [UIView animateWithDuration:duration animations:^{
            ss.alpha = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue];
        }];
        
        // Present view animated
        view.frame = (transitionStyle == KNSemiModalTransitionStyleSlideUp
                      ? CGRectOffset(semiViewFrame, 0, +semiViewHeight)
                      : semiViewFrame);
        if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
            view.alpha = 0.0;
        }
        
        view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        view.tag = kSemiModalModalViewTag;
        [target addSubview:view];
        view.layer.shadowColor = [[UIColor blackColor] CGColor];
        view.layer.shadowOffset = CGSizeMake(0, -2);
        view.layer.shadowRadius = 5.0;
        view.layer.shadowOpacity = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.shadowOpacity] floatValue];
        view.layer.shouldRasterize = YES;
        view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        
        [UIView animateWithDuration:duration animations:^{
            if (transitionStyle == KNSemiModalTransitionStyleSlideUp) {
                view.transform = CGAffineTransformMakeTranslation(0, -1 * view.frame.size.height);
            } else if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
                view.alpha = 1.0;
            }
        } completion:^(BOOL finished) {
            if (!finished) return;
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidShowNotification
                                                                object:self];
            if (completion) {
                completion();
            }
        }];
    }
}

-(void)presentSemiView:(UIView*)view predefinedSnapshot:(UIView*)snapshot
		   withOptions:(NSDictionary*)options
			completion:(KNTransitionCompletionBlock)completion {
	[self kn_registerDefaultsAndOptions:options]; // re-registering is OK
	UIView * target = [self parentTarget];
	
    if (![target.subviews containsObject:view]) {
        // Register for orientation changes, so we can update the presenting controller screenshot
        //        [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                 selector:@selector(kn_interfaceOrientationDidChange:)
        //                                                     name:UIDeviceOrientationDidChangeNotification
        //                                                   object:nil];
        
        NSUInteger transitionStyle = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionStyle] unsignedIntegerValue];
        
        // Calulate all frames
        CGFloat semiViewHeight = view.frame.size.height;
        CGRect vf = target.bounds;
        CGRect semiViewFrame = CGRectMake(0, vf.size.height-semiViewHeight, vf.size.width, semiViewHeight);
        CGRect overlayFrame = CGRectMake(0, 0, vf.size.width, vf.size.height-semiViewHeight);
        
        // Add semi overlay
        UIView * overlay = [[UIView alloc] initWithFrame:target.bounds];
        overlay.backgroundColor = [UIColor blackColor];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.tag = kSemiModalOverlayTag;
        
        // Take screenshot and scale
        UIImageView *ss = [self snapshotWithPredefinedView:snapshot container:overlay];
        [target addSubview:overlay];
        
        objc_setAssociatedObject(self, @"ss", ss, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @"view", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Dismiss button (if allow)
        if(![[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.disableCancel] boolValue]) {
            // Don't use UITapGestureRecognizer to avoid complex handling
            UIView *gestureView = [[UIView alloc] initWithFrame:overlayFrame];
            gestureView.tag = kSemiModalDismissButtonTag;
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]  initWithTarget:self action:@selector(selfPan:)];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSemiModalView)];
            [gestureView addGestureRecognizer:tap];
            [gestureView addGestureRecognizer:pan];
            [gestureView setBackgroundColor:[UIColor clearColor]];
            [overlay addSubview:gestureView];
        }
        
        // Begin overlay animation
		if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue]) {
			[ss.layer addAnimation:[self animationGroupForward:YES] forKey:@"pushedBackAnimation"];
		}
		NSTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
        [UIView animateWithDuration:duration animations:^{
            ss.alpha = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue];
        }];
        
        // Present view animated
        view.frame = (transitionStyle == KNSemiModalTransitionStyleSlideUp
                      ? CGRectOffset(semiViewFrame, 0, +semiViewHeight)
                      : semiViewFrame);
        if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
            view.alpha = 0.0;
        }
        
        view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        view.tag = kSemiModalModalViewTag;
        [target addSubview:view];
        view.layer.shadowColor = [[UIColor blackColor] CGColor];
        view.layer.shadowOffset = CGSizeMake(0, -2);
        view.layer.shadowRadius = 5.0;
        view.layer.shadowOpacity = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.shadowOpacity] floatValue];
        view.layer.shouldRasterize = YES;
        view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        
        [UIView animateWithDuration:duration animations:^{
            if (transitionStyle == KNSemiModalTransitionStyleSlideUp) {
                //view.frame = semiViewFrame;
                view.transform = CGAffineTransformMakeTranslation(0, -1 * view.frame.size.height);
            } else if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
                view.alpha = 1.0;
            }
        } completion:^(BOOL finished) {
            if (!finished) return;
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidShowNotification
                                                                object:self];
            /*CATransform3D t2 = CATransform3DIdentity;
             t2.m34 = 1.0/-900;
             t2 = CATransform3DTranslate(t2, 0, [self parentTarget].frame.size.height*-0.08, 0);
             t2 = CATransform3DScale(t2, 0.8, 0.8, 1);
             t2 = CATransform3DRotate(t2, 15.0f*M_PI*180.0f, 1, 0, 0);
             
             
             ss.layer.transform = t2;*/
            [self setFinalTransform];
            
            if (completion) {
                completion();
            }
        }];
    }
}

-(void)presentSemiView:(UIView*)view predefinedImage:(UIImage*)image
		   withOptions:(NSDictionary*)options
			completion:(KNTransitionCompletionBlock)completion {
	[self kn_registerDefaultsAndOptions:options]; // re-registering is OK
	UIView * target = [self parentTarget];
	
    if (![target.subviews containsObject:view]) {
        // Register for orientation changes, so we can update the presenting controller screenshot
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(kn_interfaceOrientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        NSUInteger transitionStyle = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionStyle] unsignedIntegerValue];
        
        // Calulate all frames
        CGFloat semiViewHeight = view.frame.size.height;
        CGRect vf = target.bounds;
        CGRect semiViewFrame = CGRectMake(0, vf.size.height-semiViewHeight, vf.size.width, semiViewHeight);
        CGRect overlayFrame = CGRectMake(0, 0, vf.size.width, vf.size.height-semiViewHeight);
        
        // Add semi overlay
        UIView * overlay = [[UIView alloc] initWithFrame:target.bounds];
        overlay.backgroundColor = [UIColor blackColor];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.tag = kSemiModalOverlayTag;
        
        // Take screenshot and scale
        UIImageView *ss = [self snapshotWithPredefinedView:view container:overlay];
        [target addSubview:overlay];
        
        // Dismiss button (if allow)
        if(![[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.disableCancel] boolValue]) {
            // Don't use UITapGestureRecognizer to avoid complex handling
            UIButton * dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [dismissButton addTarget:self action:@selector(dismissSemiModalView) forControlEvents:UIControlEventTouchUpInside];
            dismissButton.backgroundColor = [UIColor clearColor];
            dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            dismissButton.frame = overlayFrame;
            dismissButton.tag = kSemiModalDismissButtonTag;
            [overlay addSubview:dismissButton];
        }
        
        // Begin overlay animation
		if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue]) {
			[ss.layer addAnimation:[self animationGroupForward:YES] forKey:@"pushedBackAnimation"];
		}
		NSTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
        [UIView animateWithDuration:duration animations:^{
            ss.alpha = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue];
        }];
        
        // Present view animated
        view.frame = (transitionStyle == KNSemiModalTransitionStyleSlideUp
                      ? CGRectOffset(semiViewFrame, 0, +semiViewHeight)
                      : semiViewFrame);
        if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
            view.alpha = 0.0;
        }
        
        view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        view.tag = kSemiModalModalViewTag;
        [target addSubview:view];
        view.layer.shadowColor = [[UIColor blackColor] CGColor];
        view.layer.shadowOffset = CGSizeMake(0, -2);
        view.layer.shadowRadius = 5.0;
        view.layer.shadowOpacity = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.shadowOpacity] floatValue];
        view.layer.shouldRasterize = YES;
        view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        
        [UIView animateWithDuration:duration animations:^{
            if (transitionStyle == KNSemiModalTransitionStyleSlideUp) {
                view.frame = semiViewFrame;
            } else if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
                view.alpha = 1.0;
            }
        } completion:^(BOOL finished) {
            if (!finished) return;
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidShowNotification
                                                                object:self];
            if (completion) {
                completion();
            }
        }];
    }
}

-(void)presentSemiViewForMoving:(UIView*)view
     withPredefinedSnapshotView:(UIView*)snap
                    withOptions:(NSDictionary*)options
                     completion:(KNTransitionCompletionBlock)completion {
	[self kn_registerDefaultsAndOptions:options]; // re-registering is OK
	UIView * target = [self parentTarget];
	
    if (![target.subviews containsObject:view]) {
        // Register for orientation changes, so we can update the presenting controller screenshot
        //        [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                 selector:@selector(kn_interfaceOrientationDidChange:)
        //                                                     name:UIDeviceOrientationDidChangeNotification
        //                                                   object:nil];
        NSUInteger transitionStyle = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionStyle] unsignedIntegerValue];
        
        // Calulate all frames
        CGFloat semiViewHeight = view.frame.size.height;
        CGRect vf = target.bounds;
        CGRect semiViewFrame = CGRectMake(0, vf.size.height-semiViewHeight, vf.size.width, semiViewHeight);
        CGRect overlayFrame = CGRectMake(0, 0, vf.size.width, vf.size.height-semiViewHeight);
        
        // Add semi overlay
        UIView * overlay = [[UIView alloc] initWithFrame:target.bounds];
        overlay.backgroundColor = [UIColor blackColor];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.tag = kSemiModalOverlayTag;
        
        // Take screenshot and scale
        UIImageView *ss = [self snapshotWithPredefinedView:snap container:overlay];
        objc_setAssociatedObject(self, @"ss", ss, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [target addSubview:overlay];
        
        // Dismiss button (if allow)
        if(![[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.disableCancel] boolValue]) {
            // Don't use UITapGestureRecognizer to avoid complex handling
            
            UIView *gestureView = [[UIView alloc] initWithFrame:overlayFrame];
            gestureView.tag = kSemiModalDismissButtonTag;
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]  initWithTarget:self action:@selector(selfPan:)];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSemiModalView)];
            [gestureView addGestureRecognizer:tap];
            [gestureView addGestureRecognizer:pan];
            [gestureView setBackgroundColor:[UIColor clearColor]];
            [overlay addSubview:gestureView];
        }
        /*
         // Begin overlay animation
         if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue]) {
         [ss.layer addAnimation:[self animationGroupForward:YES] forKey:@"pushedBackAnimation"];
         }
         NSTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
         [UIView animateWithDuration:duration animations:^{
         ss.alpha = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue];
         }];*/
        
        // Present view animated
        view.frame = (transitionStyle == KNSemiModalTransitionStyleSlideUp
                      ? CGRectOffset(semiViewFrame, 0, +semiViewHeight)
                      : semiViewFrame);
        
        if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
            view.alpha = 0.0;
        }
        
        view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        view.tag = kSemiModalModalViewTag;
        [target addSubview:view];
        view.layer.shadowColor = [[UIColor blackColor] CGColor];
        view.layer.shadowOffset = CGSizeMake(0, -2);
        view.layer.shadowRadius = 5.0;
        view.layer.shadowOpacity = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.shadowOpacity] floatValue];
        view.layer.shouldRasterize = YES;
        view.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        objc_setAssociatedObject(self, @"view", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        objc_setAssociatedObject(self, @"completion", completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        /*
         [UIView animateWithDuration:duration animations:^{
         if (transitionStyle == KNSemiModalTransitionStyleSlideUp) {
         view.frame = semiViewFrame;
         } else if (transitionStyle == KNSemiModalTransitionStyleFadeIn || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
         view.alpha = 1.0;
         }
         } completion:^(BOOL finished) {
         if (!finished) return;
         [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidShowNotification
         object:self];
         if (completion) {
         completion();
         }
         }];*/
    }
}

-(void)finishMovingSemiViewControllerUpWithPercent:(float)percent {
    [self animateRestOfWayUpWithPercent:percent];
}

-(void)finishMovingSemiViewControllerDownWithPercent:(float)percent {
    [self animateRestOfWayDownWithPercent:percent];
}

-(void)dismissSemiModalView {
	[self dismissSemiModalViewWithCompletion:nil];
}

-(void)dismissSemiModalViewWithCompletion:(void (^)(void))completion {
    UIView * target = [self parentTarget];
    UIView * modal = [target.subviews objectAtIndex:target.subviews.count-1];
    UIView * overlay = [target.subviews objectAtIndex:target.subviews.count-2];
	NSUInteger transitionStyle = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionStyle] unsignedIntegerValue];
	NSTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
	UIViewController *vc = objc_getAssociatedObject(self, kSemiModalViewController);
	KNTransitionCompletionBlock dismissBlock = objc_getAssociatedObject(self, kSemiModalDismissBlock);
	
	// child controller containment
	[vc willMoveToParentViewController:nil];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:NO animated:YES]; // iOS 6
	}
	
    [UIView animateWithDuration:duration animations:^{
        if (transitionStyle == KNSemiModalTransitionStyleSlideUp) {
            //modal.frame = CGRectMake(0, target.bounds.size.height, modal.frame.size.width, modal.frame.size.height);
            modal.transform = CGAffineTransformMakeTranslation(0, 0);
        } else if (transitionStyle == KNSemiModalTransitionStyleFadeOut || transitionStyle == KNSemiModalTransitionStyleFadeInOut) {
            modal.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
        [modal removeFromSuperview];
        
        // child controller containment
        [vc removeFromParentViewController];
        if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
            [vc endAppearanceTransition];
        }
        
        if (dismissBlock) {
            dismissBlock();
        }
        
        objc_setAssociatedObject(self, kSemiModalDismissBlock, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(self, kSemiModalViewController, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    }];
    
    // Begin overlay animation
    UIImageView * ss = (UIImageView*)[overlay.subviews objectAtIndex:0];
	if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue]) {
		[ss.layer addAnimation:[self animationGroupForward:NO] forKey:@"bringForwardAnimation"];
	}
    [UIView animateWithDuration:duration animations:^{
        ss.alpha = 1;
    } completion:^(BOOL finished) {
        if(finished){
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidHideNotification
                                                                object:self];
            if (completion) {
                completion();
            }
        }
    }];
}



- (void)resizeSemiView:(CGSize)newSize {
    UIView * target = [self parentTarget];
    UIView * modal = [target.subviews objectAtIndex:target.subviews.count-1];
    CGRect mf = modal.frame;
    mf.size.width = newSize.width;
    mf.size.height = newSize.height;
    mf.origin.y = target.frame.size.height - mf.size.height;
    UIView * overlay = [target.subviews objectAtIndex:target.subviews.count-2];
    UIButton * button = (UIButton*)[overlay viewWithTag:kSemiModalDismissButtonTag];
    CGRect bf = button.frame;
    bf.size.height = overlay.frame.size.height - newSize.height;
	NSTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
	[UIView animateWithDuration:duration animations:^{
        modal.frame = mf;
        button.frame = bf;
    } completion:^(BOOL finished) {
        if(finished){
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalWasResizedNotification
                                                                object:self];
        }
    }];
}

@end

#pragma mark -

// Convenient category method to find actual ViewController that contains a view
// Adapted from: http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

@implementation UIView (FindUIViewController)
- (UIViewController *) containingViewController {
    UIView * target = self.superview ? self.superview : self;
    return (UIViewController *)[target traverseResponderChainForUIViewController];
}

- (id) traverseResponderChainForUIViewController {
    id nextResponder = [self nextResponder];
    BOOL isViewController = [nextResponder isKindOfClass:[UIViewController class]];
    BOOL isTabBarController = [nextResponder isKindOfClass:[UITabBarController class]];
    if (isViewController && !isTabBarController) {
        return nextResponder;
    } else if(isTabBarController){
        UITabBarController *tabBarController = nextResponder;
        return [tabBarController selectedViewController];
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForUIViewController];
    } else {
        return nil;
    }
}

@end