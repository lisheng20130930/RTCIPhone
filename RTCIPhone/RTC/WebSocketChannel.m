#import "WebSocketChannel.h"
#import <Foundation/Foundation.h>

#import "WebRTC/RTCLogging.h"
#import "SRWebSocket.h"
#import "ITransaction.h"
#import "PlugHandle.h"


//static NSString *gURL = @"ws://192.168.18.213:8188";
static NSString *gURL = @"ws://47.110.157.52:8188";


typedef NS_ENUM(NSInteger, ARDSignalingChannelState) {
    kARDSignalingChannelStateClosed,
    kARDSignalingChannelStateOpen,
    kARDSignalingChannelStateError
};


static NSString const *kJanus = @"janus";
static NSString const *kJanusData = @"data";


@interface WebSocketChannel () <SRWebSocketDelegate>
@property(nonatomic, readonly) ARDSignalingChannelState state;
@property(nonatomic, strong) NSString *usrname;
@property(nonatomic, strong) SRWebSocket *socket;
@property(nonatomic, strong) NSNumber *sessionId;
@property(nonatomic, strong) NSTimer *keepAliveTimer;
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSMutableDictionary *transDict;
@property(nonatomic, strong) NSMutableDictionary *handleDict;
@property(nonatomic, strong) NSMutableDictionary *feedDict;
@end

@implementation WebSocketChannel

- (instancetype)initWithUsrName:(NSString *)name{
    if (self = [super init]) {
        _url = [[NSURL alloc] initWithString:gURL];
        NSArray<NSString *> *protocols = [NSArray arrayWithObject:@"janus-protocol"];
        _socket = [[SRWebSocket alloc] initWithURL:_url protocols:(NSArray *)protocols];
        _socket.delegate = self;
        _keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(keepAlive) userInfo:nil repeats:YES];
        _transDict = [NSMutableDictionary dictionary];
        _handleDict = [NSMutableDictionary dictionary];
        _feedDict = [NSMutableDictionary dictionary];
        _usrname = name;
        RTCLog(@"Opening WebSocket.");
        [_socket open];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"websocket ===> dealloc... now....");
}

- (void)setState:(ARDSignalingChannelState)state {
  if (_state == state) {
    return;
  }
  _state = state;
}

- (void)disconnect {
  if (_state == kARDSignalingChannelStateClosed ||
      _state == kARDSignalingChannelStateError) {
    return;
  }
  [_socket close];
    RTCLog(@"C->WSS DELETE close");
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
  RTCLog(@"WebSocket connection opened.");
  self.state = kARDSignalingChannelStateOpen;
  [self createSession];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
  NSLog(@"====didReceiveMessage=%@", message);
  NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
  id jsonObject = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:nil];
  if (![jsonObject isKindOfClass:[NSDictionary class]]) {
    NSLog(@"Unexpected message: %@", jsonObject);
    return;
  }
  NSDictionary *wssMessage = jsonObject;
  NSString *janus = wssMessage[kJanus];
    if ([janus isEqualToString:@"success"]) {
        NSString *transaction = wssMessage[@"transaction"];

        ITransaction *jt = _transDict[transaction];
        if (jt.success != nil) {
            jt.success(wssMessage);
        }
        [_transDict removeObjectForKey:transaction];
    } else if ([janus isEqualToString:@"error"]) {
        NSString *transaction = wssMessage[@"transaction"];
        ITransaction *jt = _transDict[transaction];
        if (jt.error != nil) {
            jt.error(wssMessage);
        }
        [_transDict removeObjectForKey:transaction];
    } else if ([janus isEqualToString:@"ack"]) {
        NSLog(@"Just an ack");
    } else {
        PlugHandle *handle = _handleDict[wssMessage[@"sender"]];
        if (handle == nil) {
            NSLog(@"missing handle?");
        } else if ([janus isEqualToString:@"event"]) {
            NSDictionary *data = wssMessage[@"plugindata"][@"data"];
            NSDictionary *jsep = wssMessage[@"jsep"];
            handle.onMessage(handle, data, jsep);
        } else if ([janus isEqualToString:@"detached"]) {
            _handleDict[handle.handleId] = nil;
        }
    }
}


- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
  RTCLogError(@"WebSocket error: %@", error);
  self.state = kARDSignalingChannelStateError;
}

- (void)webSocket:(SRWebSocket *)webSocket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    RTCLog(@"WebSocket closed with code: %ld reason:%@ wasClean:%d",
           (long)code, reason, wasClean);
    NSParameterAssert(_state != kARDSignalingChannelStateError);
    self.state = kARDSignalingChannelStateClosed;
    [_keepAliveTimer invalidate];
}

#pragma mark - Private

NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

- (NSString *)randomStringWithLength: (int)len {
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    for (int i = 0; i< len; i++) {
        uint32_t data = arc4random_uniform((uint32_t)[letters length]);
        [randomString appendFormat: @"%C", [letters characterAtIndex: data]];
    }
    return randomString;
}

- (void)createSession {
    NSString *transaction = [self randomStringWithLength:12];

    ITransaction *jt = [[ITransaction alloc] init];
    jt.tid = transaction;
    __weak typeof(self) weakSelf = self;
    jt.success = ^(NSDictionary *data) {
        weakSelf.sessionId = data[@"data"][@"id"];
        [weakSelf.keepAliveTimer fire];
        [weakSelf createHandle];
    };
    jt.error = ^(NSDictionary *data) {
    };
    _transDict[transaction] = jt;

    NSDictionary *createMessage = @{
        @"janus": @"create",
        @"transaction" : transaction,
                                    };
  [_socket send:[self jsonMessage:createMessage]];
}

- (void)createHandle {
    NSString *transaction = [self randomStringWithLength:12];
    ITransaction *jt = [[ITransaction alloc] init];
    jt.tid = transaction;
    __weak typeof(self) weakSelf = self;
    jt.success = ^(NSDictionary *data){
        PlugHandle *handle = [[PlugHandle alloc] init];
        handle.handleId = data[@"data"][@"id"];
        handle.onMessage = ^(PlugHandle *handle, NSDictionary *msg, NSDictionary *jsep){
            [weakSelf.delegate onMessage:handle.handleId msg:msg jsep:jsep];
        };
        weakSelf.handleDict[handle.handleId] = handle;
        [weakSelf registerUsrName: handle];
    };
    jt.error = ^(NSDictionary *data) {
    };
    _transDict[transaction] = jt;

    NSDictionary *attachMessage = @{
                                    @"janus": @"attach",
                                    @"plugin": @"janus.plugin.videocall",
                                    @"transaction": transaction,
                                    @"session_id": _sessionId,
                                    };
    [_socket send:[self jsonMessage:attachMessage]];
}

- (void)registerUsrName: (PlugHandle *)handle {
    NSString *transaction = [self randomStringWithLength:12];

    NSDictionary *body = @{
                           @"request": @"register",
                           @"username": _usrname,
                           @"device": @"Ios"
                           };
    NSDictionary *registerMessage = @{
                                  @"janus": @"message",
                                  @"transaction": transaction,
                                  @"session_id":_sessionId,
                                  @"handle_id":handle.handleId,
                                  @"body": body
                                  };
    
    [_socket send:[self jsonMessage:registerMessage]];
}

- (void)call2:(NSString*)callee handleId: (NSNumber *)handleId sdp: (RTCSessionDescription *)sdp {
    NSString *transaction = [self randomStringWithLength:12];

    NSDictionary *body = @{
                             @"request": @"call",
                             @"username": callee
                             };

    NSString *type = [RTCSessionDescription stringForType:sdp.type];

    NSDictionary *jsep = @{
                           @"type": type,
                          @"sdp": [sdp sdp],
                           };
    NSDictionary *offerMessage = @{
                                   @"janus": @"message",
                                   @"body": body,
                                   @"jsep": jsep,
                                   @"transaction": transaction,
                                   @"session_id": _sessionId,
                                   @"handle_id": handleId,
                                   };
    [_socket send:[self jsonMessage:offerMessage]];
}

- (void)trickleCandidate:(NSNumber *) handleId candidate: (RTCIceCandidate *)candidate {
    NSDictionary *candidateDict = @{
                                @"candidate": candidate.sdp,
                                @"sdpMid": candidate.sdpMid,
                                @"sdpMLineIndex": [NSNumber numberWithInt: candidate.sdpMLineIndex],
                                };

    NSDictionary *trickleMessage = @{
                                     @"janus": @"trickle",
                                     @"candidate": candidateDict,
                                     @"transaction": [self randomStringWithLength:12],
                                     @"session_id":_sessionId,
                                     @"handle_id":handleId,
                                     };

    NSLog(@"===trickle==%@", trickleMessage);
    [_socket send:[self jsonMessage:trickleMessage]];
}

- (void)trickleCandidateComplete:(NSNumber *) handleId {
    NSDictionary *candidateDict = @{
       @"completed": @YES,
       };
    NSDictionary *trickleMessage = @{
                                     @"janus": @"trickle",
                                     @"candidate": candidateDict,
                                     @"transaction": [self randomStringWithLength:12],
                                     @"session_id":_sessionId,
                                     @"handle_id":handleId,
                                     };

    [_socket send:[self jsonMessage:trickleMessage]];
}

- (void)accept:(NSNumber *)handleId sdp: (RTCSessionDescription *)sdp  {
    NSString *transaction = [self randomStringWithLength:12];

    NSDictionary *body = @{
                              @"request": @"accept"
                              };

    NSString *type = [RTCSessionDescription stringForType:sdp.type];

    NSDictionary *jsep = @{
                           @"type": type,
                           @"sdp": [sdp sdp],
                           };
    NSDictionary *offerMessage = @{
                                   @"janus": @"message",
                                   @"body": body,
                                   @"jsep": jsep,
                                   @"transaction": transaction,
                                   @"session_id": _sessionId,
                                   @"handle_id": handleId,
                                   };

    [_socket send:[self jsonMessage:offerMessage]];
}

- (void)hangup:(NSNumber *)handleId mix:(BOOL)mix{
    [self setRecord:handleId record:NO name:@""];
    NSString *transaction = [self randomStringWithLength:12];
    NSDictionary *body = @{
                           @"request": @"hangup",
                           @"mix": @(mix)
                           };
    NSDictionary *offerMessage = @{
                                   @"janus": @"message",
                                   @"body": body,
                                   @"transaction": transaction,
                                   @"session_id": _sessionId,
                                   @"handle_id": handleId,
                                   };
    
    [_socket send:[self jsonMessage:offerMessage]];
}

- (void)setRecord:(NSNumber *)handleId record:(BOOL)record name:(NSString*)name{
    NSString *transaction = [self randomStringWithLength:12];
    
    NSDictionary *body = @{
                           @"request": @"set",
                           @"audio": @(YES),
                           @"video": @(YES),
                           @"bitrate": @(128000),
                           @"record": @(record),
                           @"filename": name
                           };
    NSDictionary *offerMessage = @{
                                   @"janus": @"message",
                                   @"body": body,
                                   @"transaction": transaction,
                                   @"session_id": _sessionId,
                                   @"handle_id": handleId,
                                   };
    
    [_socket send:[self jsonMessage:offerMessage]];
}

- (void)keepAlive {
    NSDictionary *dict = @{
                           @"janus": @"keepalive",
                           @"session_id": _sessionId,
                           @"transaction": [self randomStringWithLength:12],
                           };
    [_socket send:[self jsonMessage:dict]];
}

- (NSString *)jsonMessage:(NSDictionary *)dict {
    NSData *message = [NSJSONSerialization dataWithJSONObject:dict
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:nil];
    NSString *messageString = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
    return messageString;
}


@end


