#import "AVChatManager.h"
#import "WebSocketChannel.h"
#import "RTCViewController.h"


@interface AVChatManager () <WebSocketDelegate>
@property (strong, nonatomic) WebSocketChannel *websocket;
@property (strong, nonatomic) NSNumber *handleId;
@end


@implementation AVChatManager

static AVChatManager *instance = nil;

+ (instancetype)getInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        RTCInitializeSSL();
        RTCSetupInternalTracer();
        instance = [[AVChatManager alloc] init];
    });
    return instance;
}

+ (void)clearnup{
    RTCShutdownInternalTracer();
    RTCCleanupSSL();
}

- (void)login:(NSString *)name completionHandler:(onLoginResult)completionHandler{
    _listener = completionHandler;
    if(_websocket){
        [_websocket disconnect];
        _websocket = nil;
    }
    _websocket = [[WebSocketChannel alloc] initWithUsrName: name];
    _websocket.delegate = self;
}

- (void)abort{
    _websocket.delegate = nil;
    _listener = nil;
    _observer = nil;
    _handler = nil;
    [_websocket disconnect];
    _websocket = nil;
}

- (void)outgoingcall:(NSString *)callee{
    [RTCViewController outgoingcall:callee];
}

- (void)incomingcall:(NSString *)caller sdp:(NSDictionary *)sdp{
    [RTCViewController incomingcall:sdp];
}

- (void)trickleCandidate:(RTCIceCandidate *)candidate{
    [_websocket trickleCandidate:_handleId candidate:candidate];
}

- (void)trickleCandidateComplete{
    [_websocket trickleCandidateComplete:_handleId];
}

- (void)accept:(RTCSessionDescription *)sdp{
    [_websocket accept:_handleId sdp:sdp];
}

- (void)record:(BOOL)record name:(NSString *)filename{
    [_websocket setRecord:_handleId record:record name:filename];
}

- (void)call2:(NSString *)callee sdp:(RTCSessionDescription *)sdp{
    [_websocket call2:callee handleId:_handleId sdp:sdp];
}

- (void)hangup{
    [_websocket hangup:_handleId];
}

- (void)onResultEvent:(NSNumber *)handleId result:(NSDictionary *)result jsep:(NSDictionary *)jsep{
    NSString *event = result[@"event"];
    if([event isEqualToString:@"registered"]){
        NSLog(@"video call registered success!!!!!!!!");
        _handleId = handleId; // save my handleId
        if(_listener){
            _listener(YES);
            _listener = nil;
        }
    }else if([event isEqualToString:@"incomingcall"]){
        NSLog(@"video call incoming call !!!!!!!!");
        if(_observer){
            _observer(result[@"username"],jsep);
            _observer = nil;
        }
    }else if([event isEqualToString:@"accepted"]){
        NSLog(@"video call accepted !!!! jesp=%@!!!!",jsep);
        if(_handler){
            [_handler onAccepted:result[@"cid"] jsep:jsep];
        }
    }else if([event isEqualToString:@"hangup"]){
        NSLog(@"video call hangup, do disconnect!!!!!!!!");
        if(_handler){
            [_handler onHangup];
        }
    }
}

- (void)onMessage:(NSNumber *)handleId msg:(NSDictionary *)msg jsep:(NSDictionary *)jsep {
    NSLog(@"RTC onMessage==>%@===jesp==>%@",msg,jsep);
    NSDictionary *result = msg[@"result"];
    if(result){
        if(result[@"event"]){
            [self onResultEvent:handleId result:result jsep:jsep];
        }
    }else{
        if(_listener){
            _listener(NO);
            _listener = nil;
        }
    }
}

- (void)onLeaving:(NSNumber *)handleId {
    return;
}

@end
