# Azioni Lovelace e nuovi servizi

NineHA 0.7.8 build 47 supporta le azioni Lovelace `call-service` e
`perform-action` nel Rebuilder nativo. Il servizio viene eseguito soltanto dopo
una conferma esplicita mostrata dall'app.

## Sintassi `call-service`

La sintassi legacy usa `action: call-service` e il campo `service`:

```yaml
tap_action:
  action: call-service
  service: script.example_nas_toggle
  confirmation:
    text: Confermi l'esecuzione dello script?
```

## Sintassi `perform-action`

La sintassi più recente usa `action: perform-action` e il campo
`perform_action`:

```yaml
tap_action:
  action: perform-action
  perform_action: light.turn_on
  target:
    entity_id: light.example_lamp
  data:
    brightness_pct: 40
```

NineHA accetta un servizio nel formato `dominio.servizio`, per esempio
`script.example_action`, `light.turn_on` o `button.press`.

## Dati inoltrati

L'action engine costruisce il payload in questo ordine:

1. copia `service_data`, quando presente;
2. aggiunge `data`, che prevale sulle chiavi omonime di `service_data`;
3. aggiunge il singolo `target.entity_id` se il payload non contiene già
   `entity_id`.

Le liste con più entità non sono ancora supportate. Usare un solo entity ID.

## Conferme e azioni sensibili

Le azioni generiche mostrano sempre una conferma prima della chiamata REST.
Un'azione `hold_action` nei domini `rest_command`, `shell_command` o
`homeassistant` usa inoltre lo stile distruttivo dell'avviso.

È possibile personalizzare il testo con la configurazione Lovelace:

```yaml
hold_action:
  action: perform-action
  perform_action: rest_command.example_stop
  confirmation:
    text: Confermi questa operazione?
```

## Configurazione locale opzionale

Le azioni generiche non richiedono modifiche ai sorgenti. Il file
`Sources/NineLocalConfig.user.h` rimane disponibile soltanto per adattatori
nativi specifici, dipendenze NAS e switch autorizzati al toggle predefinito.

Copiare l'esempio e modificare esclusivamente la copia ignorata da Git:

```bash
cp Sources/NineLocalConfig.user.h.example Sources/NineLocalConfig.user.h
```

Non inserire token, password, URL privati o altre credenziali nei file
pubblicati.

## Orientamento dello schermo

La build 47 segue l'orientamento del dispositivo. Su iPhone sono supportati
portrait e i due landscape; su iPad sono supportati anche portrait capovolto e
le due modalità landscape.
