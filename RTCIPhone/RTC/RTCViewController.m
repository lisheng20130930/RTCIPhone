
#import "RTCViewController.h"
#import "WebSocketChannel.h"
#import "WebRTC/WebRTC.h"
#import "RTCSessionDescription+JSON.h"
#import "JanusConnection.h"
#import "WebSocketChannel.h"



static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";


#define Screen_Width  ([UIScreen mainScreen].bounds.size.width)
#define Screen_Height ([UIScreen mainScreen].bounds.size.height)


@interface RTCViewController () <WebSocketDelegate,RTCPeerConnectionDelegate,RTCEAGLVideoViewDelegate>
@property (strong, nonatomic) RTCEAGLVideoView *localView;
@property (strong, nonatomic) RTCEAGLVideoView *remoteView;
@property (strong, nonatomic) UIButton *hangupBtn;
@property (nonatomic, strong) RTCPeerConnectionFactory *factory;
@property (strong, nonatomic) WebSocketChannel *websocket;
@property (strong, nonatomic) NSMutableDictionary *peerConnectionDict;
@property (strong, nonatomic) NSNumber *handleId;
@end


@implementation RTCViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _localView =  [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, Screen_Width, Screen_Height)];
    _remoteView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, Screen_Width, Screen_Height)];
    
    // mirror local
    _localView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    
    //NSURL *url = [[NSURL alloc] initWithString:@"ws://192.168.18.213:8188"];
    NSURL *url = [[NSURL alloc] initWithString:@"ws://47.110.157.52:8188"];
    _websocket = [[WebSocketChannel alloc] initWithURL: url usrname: _name];
    _websocket.delegate = self;

    _peerConnectionDict = [NSMutableDictionary dictionary];
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
    _hangupBtn = [[UIButton alloc] initWithFrame:CGRectMake((Screen_Width-120)/2, Screen_Height-150, 120, 55)];
    [_hangupBtn setBackgroundColor:[UIColor redColor]];
    [_hangupBtn setTitle:@"HangUP" forState:UIControlStateNormal];
    [self.view addSubview:_hangupBtn];
    
    [_hangupBtn addTarget:self action:@selector(hangupClicked:) forControlEvents:UIControlEventTouchUpInside];
}

-(void)dealloc{
    NSLog(@"RTCViewController dealloced");
}

-(void) hangupClicked:(UIButton*)btn{
    if(nil!=_handleId){
        [_websocket hangup:_handleId mix:nil!=_callee];
    }else{
        [_websocket disconnect];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)onLocalStream:(RTCMediaStream*)localStream{
    RTCVideoTrack *localVideoTrack = localStream.videoTracks[0];
    _localView.delegate = self;
    [self.view addSubview:_localView];
    [localVideoTrack addRenderer:self.localView];
    [self.view bringSubviewToFront:_hangupBtn];
}

- (RTCMediaStream*) createLocalMediaStream{
    RTCMediaStream *localStream = [_factory mediaStreamWithStreamId:kARDMediaStreamId];
    RTCVideoTrack *localVideoTrack = [self createLocalVideoTrack];
    if(localVideoTrack){
        [localStream addVideoTrack:localVideoTrack];
        [self onLocalStream:localStream];
    }
    [localStream addAudioTrack:[self createLocalAudioTrack]];
    return localStream;
}

- (RTCEAGLVideoView *)createRemoteView {
    CGRect bounds = CGRectMake(Screen_Width*3/4-5, Screen_Height*3/4-5, Screen_Width/4, Screen_Height/4);
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

- (RTCPeerConnection*)createMPeerConnection {
    RTCPeerConnection *peerConnection = [self createPeerConnection];
    [peerConnection addStream:[self createLocalMediaStream]];
    return peerConnection;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true" };
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil  optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCPeerConnection *)createPeerConnection {
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    RTCPeerConnection *peerConnection = [_factory peerConnectionWithConfiguration:config
                                         constraints:constraints
                                            delegate:self];
    return peerConnection;
}

- (void)call: (NSNumber*) handleId {
    JanusConnection *jc = [[JanusConnection alloc] init];
    jc.connection = [self createMPeerConnection];
    jc.handleId = handleId;
    _peerConnectionDict[handleId] = jc;
    __weak typeof(self) weakSelf = self;
    NSString *callee = _callee;
    [jc.connection offerForConstraints:[self defaultOfferConstraints]
                       completionHandler:^(RTCSessionDescription *sdp,
                                           NSError *error) {
                           [jc.connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                               [weakSelf.websocket call2: callee handleId: handleId sdp:sdp];
                           }];
                       }];
}

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSDictionary *mandatoryConstraints = @{ kRTCMediaConstraintsLevelControl : kRTCMediaConstraintsValueFalse };
    RTCMediaConstraints *constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"true"
                                           };
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
    return constraints;
}

- (RTCAudioTrack *)createLocalAudioTrack {
    RTCAudioTrack *track = [_factory audioTrackWithTrackId:kARDAudioTrackId];
    return track;
}

- (nullable NSDictionary *)currentMediaConstraint {
    NSDictionary *mediaConstraintsDictionary = nil;
    NSString *frameRateConstrait = @"15";
    mediaConstraintsDictionary = @{
                                   kRTCMediaConstraintsMaxWidth : @"960",
                                   kRTCMediaConstraintsMaxHeight : @"540",
                                   kRTCMediaConstraintsMaxFrameRate: frameRateConstrait
                                   };
    return mediaConstraintsDictionary;
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCMediaConstraints *cameraConstraints = [[RTCMediaConstraints alloc]
                                              initWithMandatoryConstraints:[self currentMediaConstraint]
                                              optionalConstraints: nil];
    RTCAVFoundationVideoSource *source = [_factory avFoundationVideoSourceWithConstraints:cameraConstraints];
    RTCVideoTrack *localVideoTrack = [_factory videoTrackWithSource:source trackId:kARDVideoTrackId];
    return localVideoTrack;
}

- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    CGRect bounds = CGRectMake(0, 0, Screen_Width, Screen_Height);
    if(videoView==_localView&&_localView.frame.size.width<Screen_Width/2){
        bounds = CGRectMake(Screen_Width*3/4-5, Screen_Height*3/4-5, Screen_Width/4, Screen_Height/4);
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


- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    NSLog(@"=========didAddStream");
    JanusConnection *janusConnection;

    for (NSNumber *key in _peerConnectionDict) {
        JanusConnection *jc = _peerConnectionDict[key];
        if (peerConnection == jc.connection) {
            janusConnection = jc;
            break;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (stream.videoTracks.count) {
            RTCVideoTrack *remoteVideoTrack = stream.videoTracks[0];
            RTCEAGLVideoView *remoteView = [self createRemoteView];
            [remoteVideoTrack addRenderer:remoteView];
            janusConnection.videoTrack = remoteVideoTrack;
            janusConnection.videoView = remoteView;
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    NSLog(@"=========didRemoveStream");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    NSLog(@"=========didGenerateIceCandidate==%@", candidate.sdp);

    NSNumber *handleId;
    for (NSNumber *key in _peerConnectionDict) {
        JanusConnection *jc = _peerConnectionDict[key];
        if (peerConnection == jc.connection) {
            handleId = jc.handleId;
            break;
        }
    }
    if (candidate != nil) {
        [_websocket trickleCandidate:handleId candidate:candidate];
    } else {
        [_websocket trickleCandidateComplete: handleId];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    NSLog(@"=========didRemoveIceCandidates");
}

- (void)onMessage:(NSNumber *)handleId msg:(NSDictionary *)msg jsep:(NSDictionary *)jsep {
    NSLog(@"RTC onMessage==>%@===jesp==>%@",msg,jsep);
    NSDictionary *result = msg[@"result"];
    if(nil==result){
        return;
    }
    NSString *event = result[@"event"];
    if([event isEqualToString:@"registered"]){
        NSLog(@"video call registered success!!!!!!!!");
        self.handleId = handleId; // save my handleId
        if(nil!=_callee){
            [self call:handleId];
        }
    }else if([event isEqualToString:@"incomingcall"]){
        NSLog(@"video call incoming call !!!!!!!!");
        __weak typeof(self) weakSelf = self;
        JanusConnection *jc = [[JanusConnection alloc] init];
        jc.connection = [self createMPeerConnection];
        jc.handleId = handleId;
        _peerConnectionDict[handleId] = jc;
        
        RTCSessionDescription *answerDescription = [RTCSessionDescription descriptionFromJSONDictionary:jsep];
        [jc.connection setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
        }];
        
        NSDictionary *mandatoryConstraints = @{
                                               @"OfferToReceiveAudio" : @"true",
                                               @"OfferToReceiveVideo" : @"true",
                                               };
        RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
        
        [jc.connection answerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            [jc.connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
            }];
            [weakSelf.websocket accept:handleId sdp:sdp];
        }];
    }else if([event isEqualToString:@"accepted"]){
        NSLog(@"video call accepted !!!! jesp=%@!!!!",jsep);
        if(nil!=jsep){
            JanusConnection *jc = _peerConnectionDict[handleId];
            RTCSessionDescription *answerDescription = [RTCSessionDescription descriptionFromJSONDictionary:jsep];
            [jc.connection setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
                NSLog(@" set remote description done");
            }];
        }
        //set record
        NSString *name = [NSString stringWithFormat:@"%@%@",result[@"cid"],(nil!=_callee)?@"-caller":@"-callee"];
        [_websocket setRecord: handleId record:YES name:name];
    }else if([event isEqualToString:@"hangup"]){
        NSLog(@"video call hangup, do disconnect!!!!!!!!");
        [_websocket disconnect];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
