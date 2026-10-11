#import <UIKit/UIKit.h>

@class NineMoreInfoPanel;
@class NineNASAdapter;

@protocol NineMoreInfoDelegate <NSObject>

- (void)moreInfo:(NineMoreInfoPanel *)panel
     callService:(NSString *)service
          domain:(NSString *)domain
        entityID:(NSString *)entityID
            data:(NSDictionary *)data;

- (void)moreInfo:(NineMoreInfoPanel *)panel
   nasPowerForce:(BOOL)force;

// Scelta da un elenco (sorgente, velocità di aspirazione...).
- (void)moreInfo:(NineMoreInfoPanel *)panel
      chooseFrom:(NSArray *)options
           title:(NSString *)title
         current:(NSString *)current
          source:(UIView *)source
      completion:(void (^)(NSString *choice))completion;

- (void)moreInfoDidClose:(NineMoreInfoPanel *)panel;

@end

/*
 * Pannello dettagli entità, equivalente al dialog "more-info"
 * del frontend Home Assistant. Viene mostrato sopra la vista
 * del navigation controller, senza push di controller.
 */
@interface NineMoreInfoPanel : UIView

@property (nonatomic, weak) id<NineMoreInfoDelegate> delegate;
@property (nonatomic, copy, readonly) NSString *entityID;

/*
 * related: entità collegate allo stesso dispositivo, per esempio
 * @{@"remote": entity_id, @"battery": entity_id}; relatedStates ne
 * contiene gli stati e viene aggiornato con updateRelatedStates:.
 */
- (instancetype)initWithEntity:(NSDictionary *)entity
                      registry:(NSDictionary *)registry
                          area:(NSString *)area
                           nas:(NineNASAdapter *)nas
                       related:(NSDictionary *)related
                 relatedStates:(NSDictionary *)relatedStates;

@property (nonatomic, copy, readonly) NSDictionary *related;
- (void)updateRelatedStates:(NSDictionary *)relatedStates;

- (void)showInView:(UIView *)host;
- (void)updateEntity:(NSDictionary *)entity;
- (void)refreshNAS;
- (void)dismiss;

@end
