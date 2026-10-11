#import <Foundation/Foundation.h>

extern NSString *const NineCustomDashboardsChangedNotification;

/*
 * Dashboard personalizzate, salvate localmente per server:
 *
 *   @{ @"id": @"…", @"name": @"Cucina e TV", @"icon": @"mdi:…",
 *      @"sections": @[ @{ @"title": @"Luci", @"items": @[entity_id…] } ] }
 *
 * Contengono solo identificativi di entità, mai stati o credenziali.
 */
@interface NineCustomDashboards : NSObject

+ (NSArray *)dashboardsForServer:(NSString *)server;
+ (NSDictionary *)dashboardWithID:(NSString *)identifier server:(NSString *)server;

+ (NSString *)createDashboardNamed:(NSString *)name server:(NSString *)server;
+ (void)saveDashboard:(NSDictionary *)dashboard server:(NSString *)server;
+ (void)deleteDashboardWithID:(NSString *)identifier server:(NSString *)server;

// Aggiunge l'entità alla prima sezione (creandola se serve).
+ (void)addEntity:(NSString *)entityID
      toDashboard:(NSString *)identifier
           server:(NSString *)server;

// Dashboard mostrata all'avvio (nil = panoramica automatica).
+ (NSString *)startDashboardIDForServer:(NSString *)server;
+ (void)setStartDashboardID:(NSString *)identifier server:(NSString *)server;

@end
