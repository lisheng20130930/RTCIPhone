
#import "ViewController.h"
#import "RTCViewController.h"


@implementation ViewController
- (IBAction)onCallBtnClicked:(id)sender {
    NSLog(@"oncall button clicked");
    RTCViewController *vc = [[RTCViewController alloc] init];
    vc.name = @"lisheng";
    vc.callee = @"zhangsan";
    [self presentViewController:vc animated:YES completion:nil];
}
- (IBAction)onWaitClicked:(id)sender {
    NSLog(@"on wait button clicked");
    RTCViewController *vc = [[RTCViewController alloc] init];
    vc.name = @"zhangsan";
    vc.callee = nil;
    [self presentViewController:vc animated:YES completion:nil];
}

@end
