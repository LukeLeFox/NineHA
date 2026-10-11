#import <UIKit/UIKit.h>

/*
 * Editor di una dashboard personalizzata: nome, avvio, sezioni
 * ed entità (aggiunta da ricerca, riordino e rimozione).
 * Ogni modifica viene salvata subito in NineCustomDashboards.
 */
@interface NineDashboardEditor : UITableViewController

- (instancetype)initWithServerURL:(NSString *)serverURL
                      dashboardID:(NSString *)dashboardID
                           states:(NSDictionary *)stateByID
                         registry:(NSDictionary *)registry;

#ifdef NINEHA_DEBUG_HOOKS
- (void)debugOpenPicker;
#endif

@end

// Elenco ricercabile di entità con selezione multipla.
@interface NineEntityPicker : UITableViewController

- (instancetype)initWithStates:(NSDictionary *)stateByID
                      registry:(NSDictionary *)registry
                      selected:(NSArray *)selected
                    completion:(void (^)(NSArray *selected))completion;

@end
