# Sicurezza

## Dati da non pubblicare

Non aprire issue contenenti token Home Assistant, cookie, URL privati, indirizzi
IP pubblici, configurazioni complete o altri segreti. Revocare immediatamente
qualsiasi credenziale esposta accidentalmente.

Il file `Sources/NineLocalConfig.user.h` è destinato alle sole personalizzazioni
locali ed è escluso dal repository. Non deve comunque contenere credenziali.

## Segnalazioni

Per una vulnerabilità che richiede riservatezza, usare la funzione privata
"Report a vulnerability" della scheda Security del repository GitHub. Per bug
senza impatto di sicurezza è sufficiente una normale issue.

## Piattaforma legacy

NineHA è destinato a iOS 9 e può essere usato su dispositivi jailbroken. Queste
piattaforme hanno limitazioni e rischi non risolvibili dall'applicazione. Usare
HTTPS o una VPN, limitare l'accesso di rete e assegnare al token Home Assistant
soltanto i privilegi necessari.
