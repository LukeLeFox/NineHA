# Changelog

## 0.8.0 build 48

- nuova dashboard nativa in stile app ufficiale Home Assistant: tema scuro HA,
  badge, schede per stanza, tile card e pannello dettagli;
- icone Material Design Icons incluse nell'app;
- nuova schermata iniziale e accesso con nome utente e password (login flow
  Home Assistant, con verifica in due passaggi);
- rimossi Lovelace Rebuilder e Lovelace in WebView;
- adattatore NAS nativo: stato letto dai sensori anche quando lo switch è
  `unavailable`, con avvio/arresto in corso e arresto forzato;
- corretto il ping WebSocket, che riutilizzava sempre lo stesso id e faceva
  cadere la connessione live dopo circa un minuto;
- valori numerici con formato italiano e precisione del registro, date
  relative ("2 giorni fa") per i sensori timestamp;
- aggiornamento live predefinito.

## 0.7.8 build 47

- abilitate le azioni Lovelace generiche `call-service` e `perform-action`,
  mantenendo conferma esplicita prima dell'esecuzione;
- inoltrati al servizio Home Assistant `data`, `service_data` ed eventuale
  `target.entity_id` della card;
- dichiarati gli orientamenti portrait e landscape per iPhone e iPad, con
  supporto portrait capovolto su iPad;
- verificati rotazione, avvio e azione NAS su iPad mini di prima generazione;
- mantenuta la configurazione locale opzionale separata dai sorgenti e
  dall'IPA pubblica.

## 0.7.7 build 46

- aggiunta una nuova icona originale NineHA;
- incluse le dimensioni legacy richieste da iPhone e iPad su iOS 9;
- mantenuta invariata la compatibilità ARMv7 e la versione applicativa 0.7.7.

## 0.7.7 build 45

- verificata l'installazione e l'esecuzione su iPad mini di prima generazione e
  iPhone 4S;
- layout Rebuilder responsivo per rotazione e ridimensionamento;
- stile scuro compatto per luci e altri domini controllabili;
- griglie sensori a tre colonne e valori più leggibili;
- card meteo e orologio adattive;
- bridge nativi per Mushroom, Button Card, Bubble Card ed Entity Progress Card;
- pannello dettagli entità e supporto di base a `media-control`;
- aggiornamenti live WebSocket con fallback REST;
- configurazione locale opzionale separata dai sorgenti pubblici.
