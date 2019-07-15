
#import <Foundation/Foundation.h>
#import "WebRTC/WebRTC.h"

@protocol WebSocketDelegate <NSObject>
- (void)onMessage:(NSNumber *)handleId msg:(NSDictionary*)msg jsep:(NSDictionary*)jsep;
- (void)onLeaving:(NSNumber *)handleId;
@end


@interface WebSocketChannel : NSObject

@property(nonatomic, weak) id<WebSocketDelegate> delegate;

- (instancetype)initWithUsrName:(NSString*)name;
- (void)trickleCandidate:(NSNumber *)handleId candidate: (RTCIceCandidate *)candidate;
- (void)trickleCandidateComplete:(NSNumber *)handleId;
- (void)call2:(NSString*)callee handleId: (NSNumber *)handleId sdp:(RTCSessionDescription *)sdp;
- (void)accept:(NSNumber *)handleId sdp: (RTCSessionDescription *)sdp;
- (void)setRecord:(NSNumber *)handleId record:(BOOL)record name:(NSString*)name;
- (void)hangup:(NSNumber *)handleId mix:(BOOL)mix;
- (void)disconnect;

@end
