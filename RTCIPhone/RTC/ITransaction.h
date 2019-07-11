#import <Foundation/Foundation.h>

typedef void (^TransactionSuccessBlock)(NSDictionary *data);
typedef void (^TransactionErrorBlock)(NSDictionary *data);

@interface ITransaction : NSObject

@property (nonatomic, readwrite) NSString *tid;
@property (copy) TransactionSuccessBlock success;
@property (copy) TransactionErrorBlock error;

@end
