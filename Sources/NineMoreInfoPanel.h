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

- (instancetype)initWithEntity:(NSDictionary *)entity
                      registry:(NSDictionary *)registry
                          area:(NSString *)area
                           nas:(NineNASAdapter *)nas;

- (void)showInView:(UIView *)host;
- (void)updateEntity:(NSDictionary *)entity;
- (void)refreshNAS;
- (void)dismiss;

@end
