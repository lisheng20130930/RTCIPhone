#import "RTCViewController.h"
#import "RTCClient.h"


static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";


#define Screen_Width  ([UIScreen mainScreen].bounds.size.width)
#define Screen_Height ([UIScreen mainScreen].bounds.size.height)


@interface RTCViewController () <RTCClientDelegate,RTCEAGLVideoViewDelegate>
@property (strong, nonatomic) RTCEAGLVideoView *localView;
@property (strong, nonatomic) RTCEAGLVideoView *remoteView;
@property (strong, readwrite) RTCVideoTrack *videoTrack;
@property (strong, nonatomic) UIButton *hangupBtn;
@property (strong, nonatomic) RTCClient *client;
@end


@implementation RTCViewController

+ (UIViewController*)getTopRootViewController{
    UIViewController *topRootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while(topRootViewController.presentedViewController){
        topRootViewController = topRootViewController.presentedViewController;
    }
    return topRootViewController;
}

+ (void)incomingcall:(NSDictionary *)jesp{
    UIViewController *topRootViewController = [RTCViewController getTopRootViewController];
    RTCViewController *vc = [[RTCViewController alloc] init];
    vc.jsep = jesp;
    [topRootViewController presentViewController:vc animated:YES completion:nil];
}

+ (void)outgoingcall:(NSString *)callee{
    UIViewController *topRootViewController = [RTCViewController getTopRootViewController];
    RTCViewController *vc = [[RTCViewController alloc] init];
    vc.callee = callee;
    [topRootViewController presentViewController:vc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _client = [[RTCClient alloc] init];
    _client.delegate = self;

    _localView =  [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, Screen_Width, Screen_Height)];
    _remoteView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, Screen_Width, Screen_Height)];
    
    // mirror local
    _localView.transform = CGAffineTransformMakeScale(-1.0, 1.0);

    _hangupBtn = [[UIButton alloc] initWithFrame:CGRectMake((Screen_Width-120)/2, Screen_Height-150, 120, 55)];
    [_hangupBtn setBackgroundColor:[UIColor redColor]];
    [_hangupBtn setTitle:@"HangUP" forState:UIControlStateNormal];
    [self.view addSubview:_hangupBtn];
    
    [_hangupBtn addTarget:self action:@selector(hangupClicked:) forControlEvents:UIControlEventTouchUpInside];

    [_client start:_callee jsep:_jsep];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)viewWillDisappear:(BOOL)animated{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    NSLog(@"RTCViewController ===> dealloc... now....");
}

-(void) hangupClicked:(UIButton*)btn{
    [_client hangup];
}

- (void)onHangup {
    if(_videoTrack){ //remove Track
        [_videoTrack removeRenderer:_remoteView];
        _remoteView.delegate = nil;
        _videoTrack = nil;
    }
    [_client abort];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onLocalStream:(RTCMediaStream *)stream {
    RTCVideoTrack *localVideoTrack = stream.videoTracks[0];
    _localView.delegate = self;
    [self.view addSubview:_localView];
    [localVideoTrack addRenderer:_localView];
    [self.view bringSubviewToFront:_hangupBtn];
}

- (RTCEAGLVideoView *)getRemoteView {
    CGRect bounds = CGRectMake(Screen_Width*3/4-5, 30, Screen_Width/4, Screen_Height/4);
    CGSize size = CGSizeMake(_localView.frame.size.width/4, _localView.frame.size.height/4);
    CGRect rect = CGRectZero;
    if(size.width/size.height>=bounds.size.width/bounds.size.height){
        float w = size.width * bounds.size.height/size.height;
        rect = CGRectMake(bounds.origin.x+(bounds.size.width-w)/2, bounds.origin.y, w, bounds.size.height);
    }else{
        rect = AVMakeRectWithAspectRatioInsideRect(size, bounds);
    }
    _localView.frame = rect;
    
    _remoteView.delegate = self;
    [self.view addSubview:_remoteView];
    
    [self.view bringSubviewToFront:_localView];
    [self.view bringSubviewToFront:_hangupBtn];
    
    return _remoteView;
}

- (void)onRemoteStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (stream.videoTracks.count>0) {
            self.videoTrack = stream.videoTracks[0];
            [self.videoTrack addRenderer:[self getRemoteView]];
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0F * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [_client setAudioStreamType:YES];
    });
}

- (void)onRemoveRemoteStream:(RTCMediaStream *)stream {
    if(_videoTrack){
        [_videoTrack removeRenderer:_remoteView];
        _remoteView.delegate = nil;
        _videoTrack = nil;
    }
}

- (void)videoView:(nonnull RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    CGRect bounds = CGRectMake(0, 0, Screen_Width, Screen_Height);
    if(videoView==_localView&&_localView.frame.size.width<Screen_Width/2){
        bounds = CGRectMake(Screen_Width*3/4-5, 30, Screen_Width/4, Screen_Height/4);
    }
    CGRect rect = CGRectMake(0, 0, 0, 0);
    if(size.width/size.height>=bounds.size.width/bounds.size.height){
        float w = size.width * bounds.size.height/size.height;
        rect = CGRectMake(bounds.origin.x+(bounds.size.width-w)/2, bounds.origin.y, w, bounds.size.height);
    }else{
        rect = AVMakeRectWithAspectRatioInsideRect(size, bounds);
    }
    videoView.frame = rect;
}

@end
