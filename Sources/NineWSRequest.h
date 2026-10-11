#import <Foundation/Foundation.h>

/*
 * Richiesta WebSocket "una tantum" verso Home Assistant: si
 * autentica, invia i comandi indicati e restituisce i risultati
 * nello stesso ordine, poi chiude la connessione.
 */
typedef void (^NineWSCompletion)(NSArray *results, NSError *error);

@interface NineWSRequest : NSObject

// commands: array di dizionari senza "id" (assegnato in automatico).
// results: per ogni comando il campo "result", oppure NSNull se
// Home Assistant ha risposto con success = false.
+ (NineWSRequest *)sendCommands:(NSArray *)commands
                      serverURL:(NSString *)serverURL
                          token:(NSString *)token
                     completion:(NineWSCompletion)completion;

- (void)cancel;

@end
