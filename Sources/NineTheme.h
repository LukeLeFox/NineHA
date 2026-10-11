#import <UIKit/UIKit.h>

/*
 * Palette ispirata al tema scuro predefinito del frontend
 * Home Assistant. Tutte le schermate native usano questi valori.
 */

UIColor *NTHex(unsigned int rgb, CGFloat alpha);

UIColor *NTBackground(void);     // sfondo applicazione
UIColor *NTCard(void);           // card, tile e pannelli
UIColor *NTCardPressed(void);
UIColor *NTBorder(void);         // bordo card / divisori
UIColor *NTHeader(void);         // barra superiore
UIColor *NTText(void);           // testo primario
UIColor *NTSecondaryText(void);  // testo secondario
UIColor *NTDisabledText(void);
UIColor *NTPrimary(void);        // colore primario HA
UIColor *NTInactive(void);       // icone spente
UIColor *NTError(void);
UIColor *NTSuccess(void);
UIColor *NTWarning(void);

UIFont *NTFont(CGFloat size);
UIFont *NTMediumFont(CGFloat size);
UIFont *NTBoldFont(CGFloat size);

// Stile coerente per le tabelle di impostazioni.
void NTStyleTableView(UITableView *tableView);
void NTStyleCell(UITableViewCell *cell);
void NTStyleNavigationBar(UINavigationBar *bar);
void NTApplyAppearance(void);
