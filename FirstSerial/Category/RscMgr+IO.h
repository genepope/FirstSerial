#import "RscMgr.h"
#import <Foundation/Foundation.h>

@interface RscMgr (IO)

/* data read/write methods */
- (NSData *)readData:(UInt32)length;
- (NSData *)readData;
- (int)writeData:(NSData *)data;

/* string read/write methods */
- (NSString *)readString:(UInt32)length;
- (NSString *)readString;
- (int)writeString:(NSString *)data;

@end