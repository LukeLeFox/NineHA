#import <UIKit/UIKit.h>

/*
 * Funzioni di presentazione per gli stati Home Assistant:
 * nome, icona, colore e testo dello stato in italiano,
 * con le stesse convenzioni del frontend ufficiale.
 *
 * "registry" è il dizionario facoltativo prodotto da
 * NineAreasLoader per l'entità (nome, icona, precisione).
 */

NSString *NEDomain(NSString *entityID);
NSDictionary *NEAttributes(NSDictionary *entity);
NSString *NEStateValue(NSDictionary *entity);
NSString *NEDeviceClass(NSDictionary *entity);

BOOL NEIsUnavailable(NSDictionary *entity);
BOOL NEIsActive(NSDictionary *entity);
BOOL NEIsToggleable(NSDictionary *entity);
BOOL NESupportsBrightness(NSDictionary *entity);
NSInteger NEBrightnessPercent(NSDictionary *entity);

NSString *NEName(NSDictionary *entity, NSDictionary *registry);
NSString *NEIconName(NSDictionary *entity, NSDictionary *registry);
UIColor *NEActiveColor(NSDictionary *entity);
UIColor *NEIconColor(NSDictionary *entity);

NSString *NEStateText(NSDictionary *entity, NSDictionary *registry);
NSString *NERelativeTime(NSString *isoDate);
NSString *NEWeatherConditionText(NSString *condition);
NSString *NEWeatherIcon(NSString *condition);
NSString *NEFormatNumber(double value, NSInteger precision);

// Titolo plurale del dominio, usato nelle sezioni senza stanza.
NSString *NEDomainTitle(NSString *domain);
NSInteger NEDomainOrder(NSString *domain);
