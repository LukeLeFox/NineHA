#import <Foundation/Foundation.h>

extern NSString *const NineCustomDashboardsChangedNotification;

/*
 * Dashboard personalizzate, salvate localmente per server:
 *
 *   @{ @"id": @"…", @"name": @"Cucina e TV", @"icon": @"mdi:…",
 *      @"sections": @[ @{ @"title": @"Luci", @"items": @[entity_id…],
 *                         @"style": @"tiles", @"names": @{id: nome} } ] }
 *
 * style: "tiles" (predefinito), "grid" (griglia di valori),
 * "clock" (orologio, con "format" = "24" o "12"), "weather"
 * (card meteo con previsioni, entità = primo elemento di items).
 * names: nomi personalizzati delle entità nella sezione.
 *
 * Contengono solo identificativi di entità, mai stati o credenziali.
 */
@interface NineCustomDashboards : NSObject

+ (NSArray *)dashboardsForServer:(NSString *)server;

// Crea una dashboard completa (per esempio importata da Lovelace).
+ (NSString *)createDashboardNamed:(NSString *)name
                          sections:(NSArray *)sections
                            server:(NSString *)server;

+ (NSString *)titleForStyle:(NSString *)style;
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
