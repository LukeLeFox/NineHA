#import <UIKit/UIKit.h>

/*
 * Adattatore nativo per uno switch NAS/VM configurato in
 * NineLocalConfig.user.h. Lo stato reale non arriva dallo switch
 * (spesso un template senza stato affidabile) ma da due sensori:
 *
 *   NINEHA_NAS_STATUS_ENTITY     NAS raggiungibile (online)
 *   NINEHA_NAS_VM_STATUS_ENTITY  VM in esecuzione
 *
 * NAS on              -> Online
 * NAS off, VM on      -> Avvio o arresto in corso (dalla transizione)
 * NAS off, VM off     -> Spento
 */

typedef NS_ENUM(NSInteger, NineNASLevel) {
    NineNASLevelUnknown = -1,
    NineNASLevelOff = 0,
    NineNASLevelVMRunning = 1,
    NineNASLevelOnline = 2
};

@interface NineNASAdapter : NSObject

+ (BOOL)isConfigured;
+ (BOOL)isNASEntity:(NSString *)entityID;
+ (NSArray *)dependencies;
+ (NSString *)configuredTitle;   // nil se non impostato

// Aggiorna il livello a partire dagli stati correnti.
- (void)updateWithStates:(NSDictionary *)stateByID;

// Annota una richiesta dell'utente per mostrare subito la transizione.
- (void)noteRequestedPower:(BOOL)on;

@property (nonatomic, readonly) NineNASLevel level;
@property (nonatomic, readonly) BOOL busy;          // avvio/arresto
@property (nonatomic, readonly) BOOL poweredOn;     // VM o NAS attivi
@property (nonatomic, readonly, copy) NSString *lastChanged; // ISO 8601

- (NSString *)statusText;
- (NSString *)iconName;
- (UIColor *)color;

// Servizi configurati (dominio, servizio).
+ (NSArray *)gracefulService;
+ (NSArray *)forceService;

@end
