#import <Foundation/Foundation.h>

#ifdef NINEHA_DEMO

/*
 * Casa dimostrativa usata solo dalle build "make DEMO=1" per
 * screenshot e documentazione: nessun dato reale, nessuna rete.
 */
@interface NineDemoData : NSObject

+ (NSString *)serverURL;
+ (NSString *)locationName;
+ (NSArray *)states;
+ (NSDictionary *)entityAreas;
+ (NSArray *)areaNames;
+ (NSDictionary *)areaIcons;
+ (NSDictionary *)registry;
+ (NSArray *)forecast;

@end

#endif
