#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>


typedef void (^onLoginResult)(BOOL success);
typedef void (^onIncomingCall)(NSString *caller,NSDictionary *jsep);

@protocol RTCClientInterface <NSObject>
- (void)onAccepted:(NSString *)cid jsep:(NSDictionary*)jsep;
- (void)onHangup;
@end

@interface AVChatManager : NSObject

@property (copy) onLoginResult listener;
@property (copy) onIncomingCall observer;
@property(nonatomic, weak) id<RTCClientInterface> handler;


+ (instancetype)getInstance;
- (void)login:(NSString *)name completionHandler:(onLoginResult)completionHandler;
- (void)abort;
- (void)outgoingcall:(NSString *)callee;
- (void)incomingcall:(NSString *)caller sdp:(NSDictionary *)sdp;
- (void)accept:(RTCSessionDescription *)sdp;
- (void)record:(BOOL)record name:(NSString *)filename;
- (void)call2:(NSString *)callee sdp:(RTCSessionDescription *)sdp;
- (void)hangup:(BOOL)mix;
- (void)trickleCandidate:(RTCIceCandidate *)candidate;
- (void)trickleCandidateComplete;

@end
