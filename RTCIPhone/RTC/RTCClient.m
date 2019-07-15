#import "RTCClient.h"
#import "AVChatManager.h"


static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";


@interface RTCClient() <RTCClientInterface,RTCPeerConnectionDelegate>
@property (nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic,strong) NSString *callee;
@property(readwrite,strong) RTCPeerConnection *pc;
@end


@implementation RTCClient


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

- (RTCMediaStream*) createLocalMediaStream{
    RTCMediaStream *localStream = [_factory mediaStreamWithStreamId:kARDMediaStreamId];
    RTCVideoTrack *localVideoTrack = [self createLocalVideoTrack];
    if(localVideoTrack){
        [localStream addVideoTrack:localVideoTrack];
        [_delegate onLocalStream:localStream];
    }
    [localStream addAudioTrack:[self createLocalAudioTrack]];
    return localStream;
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

- (RTCPeerConnection*)createMediaPeerConnection {
    RTCPeerConnection *peerConnection = [self createPeerConnection];
    [peerConnection addStream:[self createLocalMediaStream]];
    return peerConnection;
}

- (void)outgoingcall:(NSString *)callee{
    _callee = callee;
    _pc = [self createMediaPeerConnection];
    __weak typeof(self) weakSelf = self;
    [_pc offerForConstraints:[self defaultOfferConstraints]
                       completionHandler:^(RTCSessionDescription *sdp,
                                           NSError *error) {
                        [weakSelf.pc setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                               [[AVChatManager getInstance] call2:weakSelf.callee sdp:sdp];
                        }];
    }];
}

static NSString const *kRTCSessionDescriptionTypeKey = @"type";
static NSString const *kRTCSessionDescriptionSdpKey = @"sdp";

+ (RTCSessionDescription *)descriptionFromJSONDictionary:
(NSDictionary *)dictionary {
    NSString *typeString = dictionary[kRTCSessionDescriptionTypeKey];
    RTCSdpType type = [RTCSessionDescription typeForString:typeString];
    NSString *sdp = dictionary[kRTCSessionDescriptionSdpKey];
    return [[RTCSessionDescription alloc] initWithType:type sdp:sdp];
}

- (void)incomingcall:(NSDictionary *)jsep{
    _pc = [self createMediaPeerConnection];
        
    RTCSessionDescription *answerDescription = [RTCClient descriptionFromJSONDictionary:jsep];
    [_pc setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {}];
        
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"true",
                                       };
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
    
    __weak typeof(self) weakSelf = self;
    [_pc answerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        [weakSelf.pc setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
        }];
        [[AVChatManager getInstance] accept:sdp];
    }];
}

- (void)start:(NSString *)callee jsep:(NSDictionary *)jsep{
    [AVChatManager getInstance].handler = self;
    _factory = [[RTCPeerConnectionFactory alloc] init];
    if(callee){
        [self outgoingcall:callee];
    }else{
        [self incomingcall:jsep];
    }
}

- (void)hangup{
    [[AVChatManager getInstance] hangup:_callee!=nil];
}

- (void)dealloc {
    NSLog(@"RTCClient ===> dealloc... now....");
}

- (void)abort{
    [_pc close];
    _pc = nil;
    _delegate = nil;
    [AVChatManager getInstance].handler = nil;
    [[AVChatManager getInstance] abort];
}

- (void)onAccepted:(NSString *)cid jsep:(NSDictionary *)jsep {
    if(nil!=jsep){
        RTCSessionDescription *answerDescription = [RTCClient descriptionFromJSONDictionary:jsep];
        [_pc setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
            NSLog(@"set remote Description success %@",error);
        }];
    }
    //set record
    NSString *name = [NSString stringWithFormat:@"%@%@",cid,(nil!=_callee)?@"-caller":@"-callee"];
    [[AVChatManager getInstance] record:YES name:name];
}

- (void)onHangup{
    if(_delegate){
        [_delegate onHangup];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    NSLog(@"=========didAddStream");
    if(_delegate){
        [_delegate onRemoteStream:stream];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    NSLog(@"=========didRemoveStream");
    if(_delegate){
        [_delegate onRemoveRemoteStream:stream];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {
    NSLog(@"=========didOpenDataChannel");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    NSLog(@"=========didChangeSignalingState");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    NSLog(@"=========didGenerateIceCandidate==%@", candidate.sdp);
    if (candidate != nil) {
        [[AVChatManager getInstance] trickleCandidate:candidate];
    } else {
        [[AVChatManager getInstance] trickleCandidateComplete];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    NSLog(@"=========didChangeIceGatheringState");
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    NSLog(@"=========peerConnectionShouldNegotiate");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    NSLog(@"=========didChangeIceConnectionState");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    NSLog(@"=========didRemoveIceCandidates");
}

@end
