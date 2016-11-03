//
//  Created by Viki.
//  Copyright (c) 2014 Viki Inc. All rights reserved.
//

#import "VKVideoPlayerView.h"
#import "VKScrubber.h"
#import <QuartzCore/QuartzCore.h>
#import "DDLog.h"
#import "VKVideoPlayerConfig.h"
#import "VKFoundation.h"
#import "VKScrubber.h"
#import "VKVideoPlayerTrack.h"
#import "UIImage+VKFoundation.h"
#import "VKVideoPlayerSettingsManager.h"

#define PADDING 8

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_WARN;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@interface VKVideoPlayerView()
@property (nonatomic, strong) NSMutableArray* customControls;
@property (nonatomic, strong) NSMutableArray* portraitControls;
@property (nonatomic, strong) NSMutableArray* landscapeControls;

@property (nonatomic, assign) BOOL isControlsEnabled;
@property (nonatomic, assign) BOOL isControlsHidden;
@end

@implementation VKVideoPlayerView

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.scrubber removeObserver:self forKeyPath:@"maximumValue"];
    [self.rewindButton removeObserver:self forKeyPath:@"hidden"];
    [self.nextButton removeObserver:self forKeyPath:@"hidden"];
}

- (void)initialize {
    
    self.customControls = [NSMutableArray array];
    self.portraitControls = [NSMutableArray array];
    self.landscapeControls = [NSMutableArray array];
    [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil];
    self.view.frame = self.frame;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.view];
    
    self.titleLabel.font = THEMEFONT(@"fontRegular", DEVICEVALUE(22.0f, 16.0f));
    self.titleLabel.textColor = THEMECOLOR(@"colorFont4");
    self.titleLabel.text = @"";
    
    self.captionButton.titleLabel.font = THEMEFONT(@"fontRegular", 16.0f);
    [self.captionButton setTitleColor:THEMECOLOR(@"colorFont4") forState:UIControlStateNormal];
    
    self.videoQualityButton.titleLabel.font = THEMEFONT(@"fontRegular", 13.0f);
    [self.videoQualityButton setTitleColor:THEMECOLOR(@"colorFont4") forState:UIControlStateNormal];
    
    self.currentTimeLabel.font = THEMEFONT(@"fontRegular", DEVICEVALUE(16.0f, 12.0f));
    self.currentTimeLabel.textColor = THEMECOLOR(@"colorFont4");
    self.totalTimeLabel.font = THEMEFONT(@"fontRegular", DEVICEVALUE(16.0f, 12.0f));
    self.totalTimeLabel.textColor = THEMECOLOR(@"colorFont4");
    
    [self.scrubber addObserver:self forKeyPath:@"maximumValue" options:0 context:nil];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(durationDidLoad:) name:kVKVideoPlayerDurationDidLoadNotification object:nil];
    [defaultCenter addObserver:self selector:@selector(scrubberValueUpdated:) name:kVKVideoPlayerScrubberValueUpdatedNotification object:nil];
    
    [self.scrubber addTarget:self action:@selector(updateTimeLabels) forControlEvents:UIControlEventValueChanged];
    
    [self.controls setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.5]];
    
    [self.captionButton setTitle:[VKSharedVideoPlayerSettingsManager.subtitleLanguageCode uppercaseString] forState:UIControlStateNormal];
    
    [self.videoQualityButton setTitle:[VKSharedVideoPlayerSettingsManager videoQualityShortDescription:[VKSharedVideoPlayerSettingsManager streamKey]] forState:UIControlStateNormal];
    
    self.externalDeviceLabel.adjustsFontSizeToFitWidth = YES;
    
    [self.rewindButton addObserver:self forKeyPath:@"hidden" options:0 context:nil];
    [self.nextButton addObserver:self forKeyPath:@"hidden" options:0 context:nil];
    
    self.fullscreenButton.hidden = NO;
    
    //    for (UIButton* button in @[
    //                               self.topPortraitCloseButton
    //                               ]) {
    //        [button setBackgroundImage:[[UIImage imageWithColor:THEMECOLOR(@"colorBackground8")] imageByApplyingAlpha:0.6f] forState:UIControlStateNormal];
    //        button.layer.cornerRadius = 4.0f;
    //        button.clipsToBounds = YES;
    //    }
    //
    //    [self.topPortraitCloseButton addTarget:self action:@selector(doneButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    self.playerControlsAutoHideTime = @4.5;
    
    //    [self.scrubber setMaximumTrackImage:[UIImage imageNamed:@"VKScrubber_max_t"] forState:UIControlStateNormal];
    //    [self.progressBar setThumbImage:[UIImage imageNamed:@"VKScrubber_max_t"] forState:UIControlStateNormal];
    //    [self.progressBar setMinimumTrackImage:
    //     [[UIImage imageNamed:@"VKScrubber_min"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 4, 0, 4)]
    //                                  forState:UIControlStateNormal];
    
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    [self initialize];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

#pragma - VKVideoPlayerViewDelegates

- (IBAction)playButtonTapped:(id)sender {
    
    UIButton* playButton;
    if ([sender isKindOfClass:[UIButton class]]) {
        playButton = (UIButton*)sender;
    }
    
    if (playButton.selected)  {
        [self.delegate playButtonPressed];
        [self setPlayButtonsSelected:NO];
    } else {
        [self.delegate pauseButtonPressed];
        [self setPlayButtonsSelected:YES];
    }
}

- (IBAction)replayButtonTapped:(id)sender {
    
    _replayButton.hidden = YES;
    _playButton.hidden = NO;
    
    [self.delegate replayButtonPressed];
    [self setPlayButtonsSelected:NO];
    
}

- (IBAction)nextTrackButtonPressed:(id)sender {
    [self.delegate nextTrackButtonPressed];
}

- (IBAction)previousTrackButtonPressed:(id)sender {
    [self.delegate previousTrackButtonPressed];
}

- (IBAction)rewindButtonPressed:(id)sender {
    [self.delegate rewindButtonPressed];
}

- (IBAction)fullscreenButtonTapped:(id)sender {
    self.fullscreenButton.selected = !self.fullscreenButton.selected;
    [self.delegate fullScreenButtonTapped];
}

- (IBAction)captionButtonTapped:(id)sender {
    [self.delegate captionButtonTapped];
}

- (IBAction)videoQualityButtonTapped:(id)sender {
    [self.delegate videoQualityButtonTapped];
}

- (IBAction)doneButtonTapped:(id)sender {
    [self.delegate doneButtonTapped];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.scrubber) {
        if ([keyPath isEqualToString:@"maximumValue"]) {
            DDLogVerbose(@"scrubber Value change: %f", self.scrubber.value);
            RUN_ON_UI_THREAD(^{
                [self updateTimeLabels];
            });
        }
    }
    
    if ([object isKindOfClass:[UIButton class]]) {
        UIButton* button = object;
        if ([button isDescendantOfView:self.topControlOverlay]) {
            [self layoutTopControls];
        }
    }
}

- (void)setDelegate:(id<VKVideoPlayerViewDelegate>)delegate {
    _delegate = delegate;
    self.scrubber.delegate = delegate;
}

- (void)durationDidLoad:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSNumber* duration = [info objectForKey:@"duration"];
    [self.delegate videoTrack].totalVideoDuration = duration;
    RUN_ON_UI_THREAD(^{
        self.scrubber.maximumValue = [duration floatValue];
        self.progressBar.maximumValue = [duration floatValue];
        self.scrubber.hidden = NO;
    });
}

- (void)scrubberValueUpdated:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    RUN_ON_UI_THREAD(^{
        DDLogVerbose(@"scrubberValueUpdated: %@", [info objectForKey:@"scrubberValue"]);
        [self.scrubber setValue:[[info objectForKey:@"scrubberValue"] floatValue] animated:YES];
        [self updateTimeLabels];
    });
}

-(void)resetTimeLabelsInit{
    [self.currentTimeLabel setText:@"00:00"];
    [self.totalTimeLabel setText:@"00:00"];
    [self.progressBar setValue:0.0];
    [self.scrubber setValue:0.0];
    [self updateTimeLabels];
}

- (void)updateTimeLabels {
    DDLogVerbose(@"Updating TimeLabels: %f", self.scrubber.value);
    
    [self.currentTimeLabel setFrameWidth:100.0f];
    [self.totalTimeLabel setFrameWidth:100.0f];
    
    self.currentTimeLabel.text = [VKSharedUtility timeStringFromSecondsValue:(int)self.scrubber.value];
    [self.currentTimeLabel sizeToFit];
    [self.currentTimeLabel setFrameHeight:CGRectGetHeight(self.bottomControlOverlay.frame)];
    
    self.totalTimeLabel.text = [VKSharedUtility timeStringFromSecondsValue:(int)self.scrubber.maximumValue];
    [self.totalTimeLabel sizeToFit];
    [self.totalTimeLabel setFrameHeight:CGRectGetHeight(self.bottomControlOverlay.frame)];
    
    [self layoutSlider];
}

- (void)layoutSliderForOrientation;
{
    [self.currentTimeLabel setFrameOriginX:PADDING];
    [self.totalTimeLabel setFrameOriginX:CGRectGetWidth(self.bottomControlOverlay.frame) - self.totalTimeLabel.frame.size.width - PADDING];
    [self.scrubber setFrameOriginX:CGRectGetMaxX(self.currentTimeLabel.frame) + PADDING];
    [self.scrubber setFrameWidth:CGRectGetMinX(self.totalTimeLabel.frame) - PADDING * 2 - CGRectGetMaxX(self.currentTimeLabel.frame)];
    [self.scrubber setFrameOriginY:CGRectGetHeight(self.bottomControlOverlay.frame)/2 - CGRectGetHeight(self.scrubber.frame)/2];
    
    [self.progressBar setFrame:self.scrubber.frame];
}

- (void)layoutSlider {
    [self layoutSliderForOrientation];
}

- (void)layoutTopControls {
    
    //    CGFloat rightMargin = CGRectGetMaxX(self.topControlOverlay.frame);
    //    for (UIView* button in self.topControlOverlay.subviews) {
    //        if ([button isKindOfClass:[UIButton class]] && button != self.doneButton && !button.hidden) {
    //            rightMargin = MIN(CGRectGetMinX(button.frame), rightMargin);
    //        }
    //    }
    
    //    [self.titleLabel setFrameWidth:rightMargin - CGRectGetMinX(self.titleLabel.frame) - 20];
}

- (void)setPlayButtonsSelected:(BOOL)selected {
    self.playButton.selected = selected;
    self.bigPlayButton.selected = selected;
}

- (void)setPlayButtonsEnabled:(BOOL)enabled {
    self.playButton.enabled = enabled;
    self.bigPlayButton.enabled = enabled;
}

- (void)setControlsEnabled:(BOOL)enabled {
    
    self.captionButton.enabled = enabled;
    self.videoQualityButton.enabled = enabled;
    self.topSettingsButton.enabled = enabled;
    
    [self setPlayButtonsEnabled:enabled];
    
    self.previousButton.enabled = enabled && self.delegate.videoTrack.hasPrevious;
    self.nextButton.enabled = enabled && self.delegate.videoTrack.hasNext;
    self.scrubber.enabled = enabled;
    self.rewindButton.enabled = enabled;
    self.fullscreenButton.enabled = enabled;
    
    self.isControlsEnabled = enabled;
    
    NSMutableArray *controlList = self.customControls.mutableCopy;
    [controlList addObjectsFromArray:self.portraitControls];
    [controlList addObjectsFromArray:self.landscapeControls];
    for (UIView *control in controlList) {
        if ([control isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton*)control;
            button.enabled = enabled;
        }
    }
}

- (IBAction)handleSingleTap:(id)sender {
    [self setControlsHidden:!self.isControlsHidden];
    if (!self.isControlsHidden) {
        self.controlHideCountdown = [self.playerControlsAutoHideTime integerValue];
    }
    [self.delegate playerViewSingleTapped];
}

- (IBAction)handleSwipeLeft:(id)sender {
    [self.delegate nextTrackBySwipe];
}

- (IBAction)handleSwipeRight:(id)sender {
    [self.delegate previousTrackBySwipe];
}

- (void)setControlHideCountdown:(NSInteger)controlHideCountdown {
    if (controlHideCountdown == 0) {
        [self setControlsHidden:YES];
    } else {
        [self setControlsHidden:NO];
    }
    _controlHideCountdown = controlHideCountdown;
}

- (void)hideControlsIfNecessary {
    if (self.isControlsHidden) return;
    if (self.controlHideCountdown == -1) {
        [self setControlsHidden:NO];
    } else if (self.controlHideCountdown == 0) {
        [self setControlsHidden:YES];
    } else {
        self.controlHideCountdown--;
    }
}

- (void)setControlsHidden:(BOOL)hidden {
    DDLogVerbose(@"Controls: %@", hidden ? @"hidden" : @"visible");
    
    if (self.isControlsHidden != hidden) {
        self.isControlsHidden = hidden;
        
        if (hidden) {
            [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
                [self.controls setAlpha:0];
                [self.topControlOverlay setTransform:CGAffineTransformMakeTranslation(0, -60)];
                [self.bottomControlOverlay setTransform:CGAffineTransformMakeTranslation(0, 60)];
            } completion:^(BOOL finished) {
                
            }];
        }else{
            [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
                [self.controls setAlpha:1];
                [self.topControlOverlay setTransform:CGAffineTransformMakeTranslation(0, 0)];
                [self.bottomControlOverlay setTransform:CGAffineTransformMakeTranslation(0, 0)];
            } completion:^(BOOL finished) {
                
            }];
        }
        
        
    }
    
    [self layoutTopControls];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[VKScrubber class]] ||
        [touch.view isKindOfClass:[UIButton class]]) {
        // prevent recognizing touches on the slider
        return NO;
    }
    return YES;
}

- (void)addSubviewForControl:(UIView *)view {
    [self addSubviewForControl:view toView:self];
}
- (void)addSubviewForControl:(UIView *)view toView:(UIView*)parentView {
    [self addSubviewForControl:view toView:parentView forOrientation:UIInterfaceOrientationMaskAll];
}
- (void)addSubviewForControl:(UIView *)view toView:(UIView*)parentView forOrientation:(UIInterfaceOrientationMask)orientation {
    view.hidden = self.isControlsHidden;
    if (orientation == UIInterfaceOrientationMaskAll) {
        [self.customControls addObject:view];
    } else if (orientation == UIInterfaceOrientationMaskPortrait) {
        [self.portraitControls addObject:view];
    } else if (orientation == UIInterfaceOrientationMaskLandscape) {
        [self.landscapeControls addObject:view];
    }
    [parentView addSubview:view];
}
- (void)removeControlView:(UIView*)view {
    [view removeFromSuperview];
    [self.customControls removeObject:view];
    [self.landscapeControls removeObject:view];
    [self.portraitControls removeObject:view];
}

@end
