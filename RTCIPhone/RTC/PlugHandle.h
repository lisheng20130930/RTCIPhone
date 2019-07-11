#import <Foundation/Foundation.h>

@class PlugHandle;

typedef void (^OnMessage)(PlugHandle *handle,NSDictionary *msg, NSDictionary *jesp);

@interface PlugHandle : NSObject

@property (readwrite, nonatomic) NSNumber *handleId;
@property (readwrite, nonatomic) NSNumber *feedId;
@property (readwrite, nonatomic) NSString *display;

@property (copy) OnMessage onMessage;

@end
