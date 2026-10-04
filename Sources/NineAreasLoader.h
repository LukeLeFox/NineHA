#import <Foundation/Foundation.h>

typedef void (^NineAreasCompletion)(
    NSDictionary *entityAreas,
    NSArray *areaNames,
    NSError *error
);

@interface NineAreasLoader : NSObject

- (instancetype)initWithServerURL:(NSString *)serverURL
                            token:(NSString *)token
                       completion:(NineAreasCompletion)completion;

- (void)start;
- (void)cancel;

@end
