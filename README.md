# NineHA

NineHA è un client Home Assistant nativo pensato per dispositivi fermi a iOS 9.
Il progetto viene compilato con Theos e Clang per ARMv7 ed è stato collaudato
principalmente su iPad mini di prima generazione; iPhone 4S è tra i dispositivi
di destinazione.

> Stato del progetto: sperimentale. NineHA non è un prodotto ufficiale di Home
> Assistant e non è affiliato a Nabu Casa.

## Funzioni principali

- autenticazione con token manuale e flusso OAuth sperimentale;
- dashboard nativa, Lovelace Rebuilder UIKit e Lovelace originale in WebView;
- aggiornamenti live tramite WebSocket, con fallback REST;
- layout Lovelace `masonry`, `grid`, `sections` e `conditional`;
- adattatori nativi per card standard e per varie card custom, tra cui Mushroom,
  Button Card, Bubble Card ed Entity Progress Card;
- supporto nativo di base per `media-control`;
- azioni `tap_action`, `hold_action`, toggle, chiamate REST e Wake-on-LAN;
- pannello nativo per la luminosità delle luci e pannello dettagli entità;
- interfaccia scura responsiva ottimizzata per schermi iPad e iPhone legacy.

Le card non riconosciute vengono mostrate come non supportate anziché essere
eseguite come codice web nel Rebuilder.

## Requisiti

- Linux;
- Theos con toolchain Clang;
- SDK iOS 9.2;
- `ideviceinstaller`/libimobiledevice per l'installazione;
- dispositivo iOS compatibile configurato per eseguire l'app.

## Compilazione

```bash
export THEOS="$HOME/theos"
make clean package FINALPACKAGE=1
```

Il pacchetto IPA viene creato nella directory `packages/`.

## Installazione

Con il dispositivo collegato:

```bash
ideviceinstaller upgrade packages/org.nineha.client_0.7.7.ipa
```

Il nome esatto del file può variare in base alla versione di Theos.

## Configurazione locale opzionale

La build pubblica non contiene entity ID, servizi o nomi appartenenti a una
specifica installazione Home Assistant. Per abilitare l'adattatore NAS e una
lista esplicita di switch con toggle predefinito:

```bash
cp Sources/NineLocalConfig.user.h.example Sources/NineLocalConfig.user.h
```

Modificare quindi soltanto `Sources/NineLocalConfig.user.h`. Il file è escluso
da Git. Non inserirvi token, password o altre credenziali.

## Privacy e sicurezza

NineHA non include URL di server, token o configurazioni personali. I token
salvati dall'app vengono conservati nel portachiavi di iOS.

Per consentire l'uso con installazioni Home Assistant locali legacy, la build
permette anche connessioni HTTP. Quando possibile usare HTTPS oppure una VPN e
non esporre direttamente Home Assistant su Internet. iOS 9 e i dispositivi
jailbroken non ricevono le protezioni di sicurezza dei sistemi moderni.

Per segnalazioni riservate consultare [SECURITY.md](SECURITY.md).

## Dipendenze

Il repository include SocketRocket nella directory `ThirdParty/SocketRocket`.
La relativa licenza è conservata accanto ai sorgenti della libreria.

## Licenze di terze parti

Le dipendenze incluse restano soggette alle rispettive licenze. Il titolare del
progetto non ha ancora scelto una licenza per il codice NineHA.
