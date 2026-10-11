#import <Foundation/Foundation.h>

/*
 * Conversione una tantum di una vista Lovelace in una dashboard
 * personalizzata di NineHA. Non è un motore Lovelace: dalle card
 * vengono ricavati solo sezioni, entità e nomi; le card senza
 * equivalente nativo vengono ignorate e conteggiate.
 */
@interface NineLovelaceImport : NSObject

// Elenco delle dashboard Lovelace: @[@{@"title", @"url_path"}...]
// (url_path NSNull = dashboard predefinita).
+ (void)loadDashboardsWithServerURL:(NSString *)serverURL
                              token:(NSString *)token
                         completion:(void (^)(NSArray *dashboards,
                                              NSError *error))completion;

// Configurazione completa di una dashboard Lovelace.
+ (void)loadConfigForURLPath:(id)urlPath
                   serverURL:(NSString *)serverURL
                       token:(NSString *)token
                  completion:(void (^)(NSDictionary *config,
                                       NSError *error))completion;

// Sezioni NineHA per una vista; skipped riceve le card ignorate.
+ (NSArray *)sectionsForView:(NSDictionary *)view skipped:(NSInteger *)skipped;

+ (NSString *)titleForView:(NSDictionary *)view index:(NSUInteger)index;

@end
