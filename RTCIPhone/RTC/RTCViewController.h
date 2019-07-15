#import <UIKit/UIKit.h>
#import "WebRTC/WebRTC.h"

@interface RTCViewController : UIViewController

@property(nonatomic,strong)NSDictionary *jsep;
@property(nonatomic,strong)NSString *callee;

+ (void)outgoingcall:(NSString *)callee;
+ (void)incomingcall:(NSDictionary *)jesp;

@end


