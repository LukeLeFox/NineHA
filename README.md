# NineHA

NineHA è un client Home Assistant nativo pensato per dispositivi fermi a iOS 9.
Il progetto viene compilato con Theos e Clang per ARMv7 ed è stato collaudato
su iPad mini di prima generazione e iPhone 4S. Su entrambi i dispositivi il
Rebuilder e le funzioni principali risultano operativi.

> Stato del progetto: sperimentale. NineHA non è un prodotto ufficiale di Home
> Assistant e non è affiliato a Nabu Casa.

## Screenshot

Le schermate in `docs/screenshots` si riferiscono alla serie 0.7 e verranno
sostituite con nuove immagini anonimizzate dell'interfaccia 0.8.

## Funzioni principali

- accesso con nome utente e password (login flow di Home Assistant, con
  verifica in due passaggi), token a lunga durata oppure OAuth;
- dashboard nativa in stile app ufficiale: tema scuro Home Assistant, badge
  (meteo, persone, luci accese), schede per stanza e tile card;
- icone Material Design Icons, le stesse del frontend, incluse le icone
  personalizzate delle entità;
- panoramica per stanza con i comandi e i sensori ambientali, scheda di ogni
  stanza con l'elenco completo raggruppato per tipo;
- pannello dettagli nativo: slider di luminosità, interruttore, tapparelle,
  termostato, lettori multimediali, scene, script e pulsanti;
- tocco sull'icona per accendere/spegnere, tocco sul tile per i dettagli,
  pressione prolungata per preferiti e per nascondere entità;
- aggiornamenti live tramite WebSocket, con fallback REST;
- adattatore nativo opzionale per uno switch NAS/VM con stato a più livelli
  (spento, avvio, online, arresto) ricavato da due sensori;
- rotazione automatica portrait/landscape, con tutti gli orientamenti su iPad.

Dalla versione 0.8 il Lovelace Rebuilder e la Lovelace in WebView sono stati
rimossi: la dashboard viene costruita dai registri di stanze ed entità di
Home Assistant, come la panoramica automatica dell'app ufficiale.

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

## Download

La build finale precompilata per ARMv7 è disponibile qui:

- [NineHA 0.7.8 build 47](Releases/NineHA-0.7.8-armv7.ipa) (serie precedente)
- [checksum SHA-256](Releases/SHA256SUMS.txt)

## Installazione

Con il dispositivo collegato:

```bash
ideviceinstaller install NineHA-0.7.8-armv7.ipa
```

Per aggiornare un'installazione già presente si può usare invece
`ideviceinstaller upgrade`. Il nome dell'IPA generata localmente può variare in
base alla versione di Theos.

## Accesso con nome utente e password

NineHA usa il [login flow](https://developers.home-assistant.io/docs/auth_api/)
documentato da Home Assistant con il provider `homeassistant`. Nel Keychain
viene salvato soltanto il refresh token: la password non è mai memorizzata.
Nella pagina Profilo > Sicurezza di Home Assistant la sessione compare con il
client `lukelefox.github.io` e può essere revocata in qualsiasi momento.

## Configurazione locale opzionale

La build pubblica non contiene entity ID, servizi o nomi appartenenti a una
specifica installazione Home Assistant. Per abilitare l'adattatore NAS e una
lista esplicita di switch con toggle predefinito:

```bash
cp Sources/NineLocalConfig.user.h.example Sources/NineLocalConfig.user.h
```

Modificare quindi soltanto `Sources/NineLocalConfig.user.h`. Il file è escluso
da Git. Non inserirvi token, password o altre credenziali.

Questa configurazione è necessaria soltanto per l'adattatore NAS: lo switch
indicato viene mostrato con lo stato ricavato dai due sensori e i comandi di
accensione/spegnimento (graceful) e arresto forzato chiedono sempre conferma.
`NINEHA_NAS_TITLE` permette di scegliere il nome mostrato sul tile.

## Privacy e sicurezza

NineHA non include URL di server, token o configurazioni personali. I token
salvati dall'app vengono conservati nel portachiavi di iOS.

Per consentire l'uso con installazioni Home Assistant locali legacy, la build
permette anche connessioni HTTP. Quando possibile usare HTTPS oppure una VPN e
non esporre direttamente Home Assistant su Internet. iOS 9 e i dispositivi
jailbroken non ricevono le protezioni di sicurezza dei sistemi moderni.

Per segnalazioni riservate consultare [SECURITY.md](SECURITY.md).

## Dipendenze

Il repository include SocketRocket nella directory `ThirdParty/SocketRocket` e
il font [Material Design Icons](https://pictogrammers.com/library/mdi/) 7.4.47
in `Resources/MDI`. Le relative licenze sono conservate accanto ai file.

## Licenza

Il codice NineHA è distribuito con licenza MIT. Le dipendenze incluse restano
soggette alle rispettive licenze, conservate nelle rispettive directory
(SocketRocket e Material Design Icons).
