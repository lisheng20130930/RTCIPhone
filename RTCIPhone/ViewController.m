
#import "ViewController.h"
#import "AVChatManager.h"


@implementation ViewController

- (IBAction)onCallBtnClicked:(id)sender {
    NSLog(@"oncall button clicked");
    [[AVChatManager getInstance] login:@"lisheng" completionHandler:^(BOOL success) {
        if(success){
            [[AVChatManager getInstance] outgoingcall:@"zhangsan"];
        }
    }];
}

- (IBAction)onWaitClicked:(id)sender {
    NSLog(@"on wait button clicked");
    [[AVChatManager getInstance] login:@"zhangsan" completionHandler:^(BOOL success) {
        if(success){
            UIButton *btn = (UIButton*)sender;
            [btn setTitle:@"等待中" forState:UIControlStateNormal];
            [AVChatManager getInstance].observer = ^(NSString *caller, NSDictionary *jsep) {
                [btn setTitle:@"等待" forState:UIControlStateNormal];
                [[AVChatManager getInstance] incomingcall:caller sdp:jsep];
            };
        }
    }];
}

-(void)dealloc{
    NSLog(@"ViewController dealloced");
}

@end
