#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>


@protocol RTCClientDelegate <NSObject>

- (void)onLocalStream:(RTCMediaStream *)stream;
- (void)onRemoteStream:(RTCMediaStream *)stream;
- (void)onRemoveRemoteStream:(RTCMediaStream *)stream;
- (void)onHangup;

@end

@interface RTCClient : NSObject

@property(nonatomic, weak) id<RTCClientDelegate> delegate;

- (void)start:(NSString *)callee jsep:(NSDictionary *)jsep;
- (void)hangup;
- (void)abort;

@end
