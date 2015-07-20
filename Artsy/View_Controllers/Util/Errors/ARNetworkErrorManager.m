#import "ARNetworkErrorManager.h"
#import "ARCustomEigenLabels.h"

@import ARAnalytics;
@import NPKeyboardLayoutGuide;


@interface ARNetworkErrorManager ()
@property (nonatomic, strong) UILabel *activeModalView;
@end


@implementation ARNetworkErrorManager

+ (ARNetworkErrorManager *)sharedManager
{
    static ARNetworkErrorManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}

+ (void)presentActiveError:(NSError *)error;
{
    [self presentActiveError:error withMessage:error.localizedDescription];
}

+ (void)presentActiveError:(NSError *)error withMessage:(NSString *)message;
{
    [ARAnalytics error:error withMessage:message];

    ARNetworkErrorManager *manager = [self sharedManager];
    if (manager.activeModalView == nil) {
        [manager presentActiveError:error withMessage:message];
    }
}

- (void)presentActiveError:(NSError *)error withMessage:(NSString *)message;
{
    ARTopMenuViewController *topMenu = [ARTopMenuViewController sharedController];
    UIViewController *hostVC = topMenu.visibleViewController;
    BOOL showOnTopMenu = topMenu.presentedViewController == nil;
    UIView *hostView = showOnTopMenu ? topMenu.tabContentView : hostVC.view;

    // This happens when there’s no network on app launch and onboarding will be shown.
    if (hostView.superview == nil) {
        return;
    }

    if ([hostVC respondsToSelector:@selector(shouldShowActiveNetworkError)]) {
        if (![(id<ARNetworkErrorAwareViewController>)hostVC shouldShowActiveNetworkError]) {
            return;
        }
    }

    self.activeModalView = [[ARWarningView alloc] initWithFrame:CGRectZero];
    self.activeModalView.text = [NSString stringWithFormat:@"%@ Network connection error.", message];

    self.activeModalView.alpha = 0;
    [hostView addSubview:self.activeModalView];

    [self.activeModalView constrainHeight:@"50"];
    [self.activeModalView constrainWidthToView:hostView predicate:nil];

    // Show banner above bottom of modal view, above tab bar of top menu, or above the keyboard.
    if (showOnTopMenu) {
        [self.activeModalView alignBottomEdgeWithView:hostView predicate:nil];
    } else {
        // Basically onboarding VCs. Still use the top menu's keyboardLayoutGuide, because it has already been loaded
        // and thus will do the correct thing when the keyboard is already shown before calling this on the VC for the
        // first time.
        [self.activeModalView alignAttribute:NSLayoutAttributeBottom
                                 toAttribute:NSLayoutAttributeTop
                                      ofView:topMenu.keyboardLayoutGuide
                                   predicate:nil];
    }

    UITapGestureRecognizer *removeTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(removeActiveError)];
    [self.activeModalView addGestureRecognizer:removeTapGesture];

    [UIView animateWithDuration:0.15 animations:^{
        self.activeModalView.alpha = 1;
    }];

    [self performSelector:@selector(removeActiveError) withObject:nil afterDelay:5];
}

- (void)removeActiveError
{
    [UIView animateWithDuration:0.25 animations:^{
        self.activeModalView.alpha = 0;

    } completion:^(BOOL finished) {
        [self.activeModalView removeFromSuperview];
        self.activeModalView = nil;
    }];
}

@end