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

/*
 * Disponibili quando la completion viene invocata con successo.
 * entityRegistry: entity_id -> @{name, icon, area, device, hidden,
 *                 category, precision}
 * areaIcons:      nome stanza -> icona mdi
 * areaNames (completion): ordine del registro Home Assistant.
 */
@property (nonatomic, readonly, strong) NSDictionary *entityRegistry;
@property (nonatomic, readonly, strong) NSDictionary *areaIcons;

- (void)start;
- (void)cancel;

@end
