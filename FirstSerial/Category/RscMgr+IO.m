#import "RscMgr+IO.h"

@implementation RscMgr (IO)

#pragma mark - NSData

- (NSData *)readData:(UInt32)length {
    UInt8 *array = (UInt8 *)malloc(sizeof(UInt8) * length);
    [self read:array Length:length];

    NSData *data = [NSData dataWithBytes:array length:length];

    free(array);
    return data;
}

- (NSData *)readData {
    return [self readData:[self getReadBytesAvailable]];
}

- (int)writeData:(NSData *)data {
    const UInt8 *array;
    array = CFDataGetBytePtr((__bridge CFDataRef)data);
    return [self write:(UInt8 *)array Length:[data length]];
}

#pragma mark - NSString

- (NSString *)readString:(UInt32)length {
    NSData *data = [self readData:length];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

- (NSString *)readString {
    return [self readString:[self getReadBytesAvailable]];
}

- (int)writeString:(NSString *)string {
    return [self writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

@end