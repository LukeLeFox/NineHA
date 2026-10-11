#import "NineEntity.h"
#import "NineTheme.h"
#import <math.h>

static NSString *NEString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

NSString *NEDomain(NSString *entityID) {
    if (![entityID isKindOfClass:[NSString class]]) return @"";
    NSRange dot = [entityID rangeOfString:@"."];
    return dot.location == NSNotFound
        ? entityID : [entityID substringToIndex:dot.location];
}

NSDictionary *NEAttributes(NSDictionary *entity) {
    id attrs = [entity isKindOfClass:[NSDictionary class]]
        ? entity[@"attributes"] : nil;
    return [attrs isKindOfClass:[NSDictionary class]] ? attrs : @{};
}

NSString *NEStateValue(NSDictionary *entity) {
    if (![entity isKindOfClass:[NSDictionary class]]) return @"unavailable";
    id state = entity[@"state"];
    if ([state isKindOfClass:[NSString class]]) return state;
    if ([state isKindOfClass:[NSNumber class]]) return [state stringValue];
    return @"unknown";
}

NSString *NEDeviceClass(NSDictionary *entity) {
    return NEString(NEAttributes(entity)[@"device_class"]) ?: @"";
}

static NSString *NEEntityID(NSDictionary *entity) {
    return [entity isKindOfClass:[NSDictionary class]]
        ? (NEString(entity[@"entity_id"]) ?: @"") : @"";
}

BOOL NEIsUnavailable(NSDictionary *entity) {
    NSString *state = NEStateValue(entity);
    return [state isEqualToString:@"unavailable"] ||
           [state isEqualToString:@"unknown"];
}

BOOL NEIsActive(NSDictionary *entity) {
    if (NEIsUnavailable(entity)) return NO;

    NSString *domain = NEDomain(NEEntityID(entity));
    NSString *state = NEStateValue(entity);

    if ([domain isEqualToString:@"cover"]) {
        return ![state isEqualToString:@"closed"];
    }
    if ([domain isEqualToString:@"climate"] ||
        [domain isEqualToString:@"humidifier"] ||
        [domain isEqualToString:@"water_heater"]) {
        return ![state isEqualToString:@"off"];
    }
    if ([domain isEqualToString:@"media_player"]) {
        return ![state isEqualToString:@"off"] &&
               ![state isEqualToString:@"standby"] &&
               ![state isEqualToString:@"idle"];
    }
    if ([domain isEqualToString:@"vacuum"]) {
        return [state isEqualToString:@"cleaning"] ||
               [state isEqualToString:@"returning"];
    }
    if ([domain isEqualToString:@"lock"]) {
        return [state isEqualToString:@"unlocked"] ||
               [state isEqualToString:@"open"];
    }
    if ([domain isEqualToString:@"person"] ||
        [domain isEqualToString:@"device_tracker"]) {
        return [state isEqualToString:@"home"];
    }

    return [state isEqualToString:@"on"];
}

BOOL NEIsToggleable(NSDictionary *entity) {
    NSString *domain = NEDomain(NEEntityID(entity));
    return [@[@"light", @"switch", @"input_boolean", @"fan"]
        containsObject:domain];
}

BOOL NESupportsBrightness(NSDictionary *entity) {
    if (![NEDomain(NEEntityID(entity)) isEqualToString:@"light"])
        return NO;

    NSDictionary *attrs = NEAttributes(entity);

    if ([attrs[@"brightness"] isKindOfClass:[NSNumber class]])
        return YES;

    NSArray *modes = attrs[@"supported_color_modes"];
    if (![modes isKindOfClass:[NSArray class]]) return NO;

    NSSet *dimmable = [NSSet setWithArray:@[
        @"brightness", @"color_temp", @"hs",
        @"xy", @"rgb", @"rgbw", @"rgbww", @"white"
    ]];

    for (id mode in modes) {
        if ([dimmable containsObject:mode]) return YES;
    }

    return NO;
}

NSInteger NEBrightnessPercent(NSDictionary *entity) {
    NSNumber *value = NEAttributes(entity)[@"brightness"];
    if (![value isKindOfClass:[NSNumber class]]) return 0;
    return MAX(1, MIN(100,
        (NSInteger)lround(value.doubleValue * 100.0 / 255.0)));
}

NSString *NEName(NSDictionary *entity, NSDictionary *registry) {
    NSString *name = NEString(NEAttributes(entity)[@"friendly_name"]);
    if (name.length) return name;

    name = NEString(registry[@"name"]);
    if (name.length) return name;

    NSString *entityID = NEEntityID(entity);
    NSRange dot = [entityID rangeOfString:@"."];
    if (dot.location != NSNotFound) {
        return [[entityID substringFromIndex:dot.location + 1]
            stringByReplacingOccurrencesOfString:@"_"
                                      withString:@" "];
    }
    return entityID.length ? entityID : @"Entità";
}

#pragma mark - Icone

static NSString *NEBatteryIcon(NSDictionary *entity) {
    double level = [NEStateValue(entity) doubleValue];
    if (NEIsUnavailable(entity)) return @"battery-unknown";

    NSInteger rounded = (NSInteger)(round(level / 10.0) * 10);
    if (rounded >= 100) return @"battery";
    if (rounded <= 0) return @"battery-outline";
    return [NSString stringWithFormat:@"battery-%ld", (long)rounded];
}

NSString *NEWeatherIcon(NSString *condition) {
    NSDictionary *icons = @{
        @"clear-night": @"weather-night",
        @"cloudy": @"weather-cloudy",
        @"exceptional": @"alert-circle-outline",
        @"fog": @"weather-fog",
        @"hail": @"weather-hail",
        @"lightning": @"weather-lightning",
        @"lightning-rainy": @"weather-lightning-rainy",
        @"partlycloudy": @"weather-partly-cloudy",
        @"pouring": @"weather-pouring",
        @"rainy": @"weather-rainy",
        @"snowy": @"weather-snowy",
        @"snowy-rainy": @"weather-snowy-rainy",
        @"sunny": @"weather-sunny",
        @"windy": @"weather-windy",
        @"windy-variant": @"weather-windy-variant"
    };
    return icons[condition ?: @""] ?: @"weather-cloudy";
}

static NSString *NEBinarySensorIcon(NSString *dc, BOOL on) {
    NSDictionary *icons = @{
        @"battery": @[@"battery-outline", @"battery"],
        @"battery_charging": @[@"battery-charging", @"battery"],
        @"carbon_monoxide": @[@"smoke-detector-alert", @"smoke-detector"],
        @"cold": @[@"snowflake", @"thermometer"],
        @"connectivity": @[@"check-network-outline", @"close-network-outline"],
        @"door": @[@"door-open", @"door-closed"],
        @"garage_door": @[@"garage-open", @"garage"],
        @"gas": @[@"alert-circle", @"check-circle"],
        @"heat": @[@"fire", @"thermometer"],
        @"light": @[@"brightness-7", @"brightness-5"],
        @"lock": @[@"lock-open", @"lock"],
        @"moisture": @[@"water", @"water-off"],
        @"motion": @[@"motion-sensor", @"motion-sensor-off"],
        @"moving": @[@"arrow-right", @"stop"],
        @"occupancy": @[@"home", @"home-outline"],
        @"opening": @[@"square-outline", @"square"],
        @"plug": @[@"power-plug", @"power-plug-off"],
        @"power": @[@"power-plug", @"power-plug-off"],
        @"presence": @[@"home", @"home-outline"],
        @"problem": @[@"alert-circle", @"check-circle"],
        @"running": @[@"play", @"stop"],
        @"safety": @[@"alert-circle", @"check-circle"],
        @"smoke": @[@"smoke-detector-variant-alert", @"smoke-detector-variant"],
        @"sound": @[@"music-note", @"music-note-off"],
        @"tamper": @[@"alert-circle", @"check-circle"],
        @"update": @[@"package-up", @"package"],
        @"vibration": @[@"vibrate", @"crop-portrait"],
        @"window": @[@"window-open", @"window-closed"]
    };

    NSArray *pair = icons[dc];
    if (pair) return pair[on ? 0 : 1];
    return on ? @"checkbox-marked-circle" : @"checkbox-blank-circle-outline";
}

static NSString *NESensorIcon(NSDictionary *entity, NSString *dc) {
    if ([dc isEqualToString:@"battery"]) return NEBatteryIcon(entity);

    NSDictionary *icons = @{
        @"apparent_power": @"flash",
        @"aqi": @"air-filter",
        @"atmospheric_pressure": @"thermometer-lines",
        @"carbon_dioxide": @"molecule-co2",
        @"carbon_monoxide": @"molecule-co",
        @"current": @"current-ac",
        @"data_rate": @"transmission-tower",
        @"data_size": @"database",
        @"date": @"calendar",
        @"distance": @"arrow-left-right",
        @"duration": @"progress-clock",
        @"energy": @"lightning-bolt",
        @"frequency": @"sine-wave",
        @"gas": @"meter-gas",
        @"humidity": @"water-percent",
        @"illuminance": @"brightness-5",
        @"moisture": @"water-percent",
        @"monetary": @"cash",
        @"pm1": @"molecule",
        @"pm10": @"molecule",
        @"pm25": @"molecule",
        @"power": @"flash",
        @"power_factor": @"angle-acute",
        @"precipitation": @"weather-rainy",
        @"pressure": @"gauge",
        @"signal_strength": @"wifi",
        @"speed": @"speedometer",
        @"temperature": @"thermometer",
        @"timestamp": @"clock-outline",
        @"voltage": @"sine-wave",
        @"volatile_organic_compounds": @"molecule",
        @"water": @"water",
        @"weight": @"weight",
        @"wind_speed": @"weather-windy"
    };

    NSString *icon = icons[dc];
    if (icon) return icon;

    NSString *unit = NEString(NEAttributes(entity)[@"unit_of_measurement"]);
    if ([unit isEqualToString:@"°C"] || [unit isEqualToString:@"°F"])
        return @"thermometer";
    if ([unit isEqualToString:@"W"] || [unit isEqualToString:@"kW"])
        return @"flash";
    if ([unit isEqualToString:@"min"] || [unit isEqualToString:@"s"] ||
        [unit isEqualToString:@"h"])
        return @"timer-outline";
    if ([unit isEqualToString:@"%"]) return @"percent-outline";

    return @"eye";
}

NSString *NEIconName(NSDictionary *entity, NSDictionary *registry) {
    NSString *custom = NEString(NEAttributes(entity)[@"icon"]);
    if (!custom.length) custom = NEString(registry[@"icon"]);
    if ([custom hasPrefix:@"mdi:"]) return custom;

    NSString *domain = NEDomain(NEEntityID(entity));
    NSString *state = NEStateValue(entity);
    NSString *dc = NEDeviceClass(entity);
    BOOL on = NEIsActive(entity);

    if ([domain isEqualToString:@"light"])
        return on ? @"lightbulb" : @"lightbulb-outline";

    if ([domain isEqualToString:@"switch"]) {
        if ([dc isEqualToString:@"outlet"])
            return on ? @"power-plug" : @"power-plug-off";
        return on ? @"toggle-switch-variant" : @"toggle-switch-variant-off";
    }

    if ([domain isEqualToString:@"input_boolean"])
        return on ? @"check-circle-outline" : @"close-circle-outline";

    if ([domain isEqualToString:@"fan"])
        return on ? @"fan" : @"fan-off";

    if ([domain isEqualToString:@"cover"]) {
        NSDictionary *pairs = @{
            @"garage": @[@"garage-open", @"garage"],
            @"door": @[@"door-open", @"door-closed"],
            @"gate": @[@"gate-open", @"gate"],
            @"window": @[@"window-open", @"window-closed"],
            @"blind": @[@"blinds-open", @"blinds"],
            @"curtain": @[@"curtains", @"curtains-closed"],
            @"awning": @[@"awning-outline", @"awning-outline"],
            @"damper": @[@"circle", @"circle-slice-8"]
        };
        NSArray *pair = pairs[dc] ?: @[@"window-shutter-open", @"window-shutter"];
        return pair[on ? 0 : 1];
    }

    if ([domain isEqualToString:@"climate"]) return @"thermostat";

    if ([domain isEqualToString:@"media_player"]) {
        if ([dc isEqualToString:@"tv"])
            return on ? @"television" : @"television-off";
        if ([dc isEqualToString:@"speaker"])
            return on ? @"speaker" : @"speaker-off";
        if ([dc isEqualToString:@"receiver"]) return @"audio-video";
        return on ? @"cast-connected" : @"cast";
    }

    if ([domain isEqualToString:@"vacuum"]) return @"robot-vacuum";

    if ([domain isEqualToString:@"lock"])
        return [state isEqualToString:@"locked"] ? @"lock" : @"lock-open-variant";

    if ([domain isEqualToString:@"person"] ||
        [domain isEqualToString:@"device_tracker"])
        return on ? @"account" : @"account-arrow-right";

    if ([domain isEqualToString:@"binary_sensor"])
        return NEBinarySensorIcon(dc, on);

    if ([domain isEqualToString:@"sensor"])
        return NESensorIcon(entity, dc);

    if ([domain isEqualToString:@"weather"]) return NEWeatherIcon(state);

    NSDictionary *icons = @{
        @"alarm_control_panel": @"shield-home",
        @"automation": @"robot",
        @"button": @"gesture-tap-button",
        @"calendar": @"calendar",
        @"camera": @"video",
        @"counter": @"counter",
        @"event": @"eye-check",
        @"humidifier": @"air-humidifier",
        @"image": @"image",
        @"input_button": @"gesture-tap-button",
        @"input_datetime": @"calendar-clock",
        @"input_number": @"ray-vertex",
        @"input_select": @"format-list-bulleted",
        @"input_text": @"form-textbox",
        @"number": @"ray-vertex",
        @"remote": @"remote",
        @"scene": @"palette",
        @"script": @"script-text",
        @"select": @"format-list-bulleted",
        @"siren": @"bullhorn",
        @"sun": @"white-balance-sunny",
        @"text": @"form-textbox",
        @"timer": @"timer-outline",
        @"todo": @"clipboard-list",
        @"update": @"package-up",
        @"water_heater": @"thermometer",
        @"zone": @"map-marker-radius"
    };

    return icons[domain] ?: @"bookmark";
}

#pragma mark - Colori

UIColor *NEActiveColor(NSDictionary *entity) {
    NSString *domain = NEDomain(NEEntityID(entity));
    NSString *state = NEStateValue(entity);
    NSString *dc = NEDeviceClass(entity);

    UIColor *amber = NTHex(0xFFC107, 1);

    if ([domain isEqualToString:@"light"] ||
        [domain isEqualToString:@"switch"] ||
        [domain isEqualToString:@"input_boolean"]) return amber;

    if ([domain isEqualToString:@"fan"]) return NTHex(0x00BCD4, 1);
    if ([domain isEqualToString:@"cover"]) return NTHex(0x926BC7, 1);
    if ([domain isEqualToString:@"media_player"]) return NTHex(0x03A9F4, 1);
    if ([domain isEqualToString:@"vacuum"]) return NTHex(0x009688, 1);
    if ([domain isEqualToString:@"person"] ||
        [domain isEqualToString:@"device_tracker"]) return NTHex(0x4CAF50, 1);
    if ([domain isEqualToString:@"lock"]) return NTHex(0xF44336, 1);

    if ([domain isEqualToString:@"climate"]) {
        if ([state isEqualToString:@"heat"]) return NTHex(0xFF8100, 1);
        if ([state isEqualToString:@"cool"]) return NTHex(0x2196F3, 1);
        if ([state isEqualToString:@"auto"]) return NTHex(0x4CAF50, 1);
        if ([state isEqualToString:@"dry"]) return NTHex(0xFF9800, 1);
        if ([state isEqualToString:@"fan_only"]) return NTHex(0x00BCD4, 1);
        return NTHex(0xFFB300, 1);
    }

    if ([domain isEqualToString:@"binary_sensor"]) {
        if ([@[@"problem", @"safety", @"smoke", @"gas", @"tamper",
               @"carbon_monoxide"] containsObject:dc])
            return NTHex(0xF44336, 1);
        if ([dc isEqualToString:@"moisture"]) return NTHex(0x2196F3, 1);
        if ([dc isEqualToString:@"connectivity"] ||
            [dc isEqualToString:@"plug"] ||
            [dc isEqualToString:@"power"] ||
            [dc isEqualToString:@"running"]) return NTHex(0x4CAF50, 1);
        return amber;
    }

    return NTPrimary();
}

UIColor *NEIconColor(NSDictionary *entity) {
    if (NEIsUnavailable(entity)) return NTDisabledText();

    NSString *domain = NEDomain(NEEntityID(entity));

    // Domini senza stato on/off: colore informativo.
    if ([@[@"sensor", @"weather", @"climate", @"scene", @"script",
           @"button", @"input_button", @"number", @"input_number",
           @"select", @"input_select", @"sun", @"update"]
            containsObject:domain] &&
        ![domain isEqualToString:@"climate"]) {
        return NTPrimary();
    }

    return NEIsActive(entity) ? NEActiveColor(entity) : NTInactive();
}

#pragma mark - Testo

NSString *NEFormatNumber(double value, NSInteger precision) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"it_IT"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
    });

    @synchronized (formatter) {
        if (precision >= 0) {
            formatter.minimumFractionDigits = precision;
            formatter.maximumFractionDigits = precision;
        } else {
            formatter.minimumFractionDigits = 0;
            formatter.maximumFractionDigits = 2;
        }
        return [formatter stringFromNumber:@(value)] ?: @"";
    }
}

static NSDate *NEParseDate(NSString *iso) {
    if (![iso isKindOfClass:[NSString class]] || iso.length < 19)
        return nil;

    static NSDateFormatter *full, *dateOnly;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        NSLocale *posix = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        full = [[NSDateFormatter alloc] init];
        full.locale = posix;
        full.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";

        dateOnly = [[NSDateFormatter alloc] init];
        dateOnly.locale = posix;
        dateOnly.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
        dateOnly.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    });

    // Rimuoviamo i decimali dei secondi (es. .061980).
    NSString *clean = iso;
    NSRange fraction = [clean rangeOfString:@"\\.[0-9]+"
                                    options:NSRegularExpressionSearch];
    if (fraction.location != NSNotFound) {
        clean = [clean stringByReplacingCharactersInRange:fraction
                                               withString:@""];
    }
    if ([clean hasSuffix:@"Z"]) {
        clean = [[clean substringToIndex:clean.length - 1]
            stringByAppendingString:@"+00:00"];
    }

    @synchronized (full) {
        return [full dateFromString:clean] ?: [dateOnly dateFromString:clean];
    }
}

NSString *NERelativeTime(NSString *isoDate) {
    NSDate *date = NEParseDate(isoDate);
    if (!date) return nil;

    NSTimeInterval delta = -[date timeIntervalSinceNow];
    BOOL future = delta < 0;
    double seconds = fabs(delta);

    NSString *amount;

    if (seconds < 45) {
        return future ? @"tra pochi secondi" : @"adesso";
    } else if (seconds < 3600) {
        NSInteger n = MAX(1, (NSInteger)lround(seconds / 60));
        amount = n == 1 ? @"1 minuto"
            : [NSString stringWithFormat:@"%ld minuti", (long)n];
    } else if (seconds < 86400) {
        NSInteger n = MAX(1, (NSInteger)lround(seconds / 3600));
        amount = n == 1 ? @"1 ora"
            : [NSString stringWithFormat:@"%ld ore", (long)n];
    } else if (seconds < 86400 * 30) {
        NSInteger n = MAX(1, (NSInteger)lround(seconds / 86400));
        amount = n == 1 ? @"1 giorno"
            : [NSString stringWithFormat:@"%ld giorni", (long)n];
    } else {
        static NSDateFormatter *output;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            output = [[NSDateFormatter alloc] init];
            output.locale = [NSLocale localeWithLocaleIdentifier:@"it_IT"];
            output.dateStyle = NSDateFormatterMediumStyle;
        });
        return [output stringFromDate:date];
    }

    return future
        ? [@"tra " stringByAppendingString:amount]
        : [amount stringByAppendingString:@" fa"];
}

NSString *NEWeatherConditionText(NSString *condition) {
    NSDictionary *names = @{
        @"clear-night": @"Sereno",
        @"cloudy": @"Nuvoloso",
        @"exceptional": @"Eccezionale",
        @"fog": @"Nebbia",
        @"hail": @"Grandine",
        @"lightning": @"Temporale",
        @"lightning-rainy": @"Temporale con pioggia",
        @"partlycloudy": @"Parzialmente nuvoloso",
        @"pouring": @"Pioggia forte",
        @"rainy": @"Pioggia",
        @"snowy": @"Neve",
        @"snowy-rainy": @"Nevischio",
        @"sunny": @"Soleggiato",
        @"windy": @"Ventoso",
        @"windy-variant": @"Ventoso e nuvoloso"
    };
    return names[condition ?: @""] ?: (condition ?: @"");
}

static NSString *NEBinaryText(NSString *dc, BOOL on) {
    NSDictionary *names = @{
        @"battery": @[@"Bassa", @"Normale"],
        @"battery_charging": @[@"In carica", @"Non in carica"],
        @"cold": @[@"Freddo", @"Normale"],
        @"connectivity": @[@"Connesso", @"Disconnesso"],
        @"door": @[@"Aperta", @"Chiusa"],
        @"garage_door": @[@"Aperta", @"Chiusa"],
        @"heat": @[@"Caldo", @"Normale"],
        @"light": @[@"Luce rilevata", @"Nessuna luce"],
        @"lock": @[@"Sbloccata", @"Bloccata"],
        @"moisture": @[@"Bagnato", @"Asciutto"],
        @"motion": @[@"Rilevato", @"Non rilevato"],
        @"moving": @[@"In movimento", @"Fermo"],
        @"occupancy": @[@"Rilevato", @"Non rilevato"],
        @"opening": @[@"Aperto", @"Chiuso"],
        @"plug": @[@"Collegato", @"Scollegato"],
        @"power": @[@"Alimentato", @"Non alimentato"],
        @"presence": @[@"A casa", @"Fuori casa"],
        @"problem": @[@"Problema", @"OK"],
        @"running": @[@"In esecuzione", @"Non in esecuzione"],
        @"safety": @[@"Non sicuro", @"Sicuro"],
        @"smoke": @[@"Rilevato", @"Assente"],
        @"gas": @[@"Rilevato", @"Assente"],
        @"carbon_monoxide": @[@"Rilevato", @"Assente"],
        @"sound": @[@"Rilevato", @"Assente"],
        @"tamper": @[@"Manomissione", @"OK"],
        @"update": @[@"Aggiornamento disponibile", @"Aggiornato"],
        @"vibration": @[@"Rilevata", @"Assente"],
        @"window": @[@"Aperta", @"Chiusa"]
    };

    NSArray *pair = names[dc];
    if (pair) return pair[on ? 0 : 1];
    return on ? @"Attivo" : @"Inattivo";
}

NSString *NEStateText(NSDictionary *entity, NSDictionary *registry) {
    NSString *entityID = NEEntityID(entity);
    NSString *domain = NEDomain(entityID);
    NSString *state = NEStateValue(entity);
    NSString *dc = NEDeviceClass(entity);
    NSDictionary *attrs = NEAttributes(entity);

    if ([state isEqualToString:@"unavailable"]) return @"Non disponibile";
    if ([state isEqualToString:@"unknown"]) return @"Sconosciuto";

    BOOL on = [state isEqualToString:@"on"];

    if ([domain isEqualToString:@"light"]) {
        if (on && NESupportsBrightness(entity) &&
            [attrs[@"brightness"] isKindOfClass:[NSNumber class]]) {
            return [NSString stringWithFormat:@"%ld%%",
                (long)NEBrightnessPercent(entity)];
        }
        return on ? @"Accesa" : @"Spenta";
    }

    if ([domain isEqualToString:@"switch"] ||
        [domain isEqualToString:@"input_boolean"] ||
        [domain isEqualToString:@"fan"] ||
        [domain isEqualToString:@"automation"] ||
        [domain isEqualToString:@"remote"] ||
        [domain isEqualToString:@"siren"]) {
        if ([state isEqualToString:@"on"]) return @"Acceso";
        if ([state isEqualToString:@"off"]) return @"Spento";
    }

    if ([domain isEqualToString:@"binary_sensor"]) {
        return NEBinaryText(dc, on);
    }

    if ([domain isEqualToString:@"person"] ||
        [domain isEqualToString:@"device_tracker"]) {
        if ([state isEqualToString:@"home"]) return @"A casa";
        if ([state isEqualToString:@"not_home"]) return @"Fuori casa";
        return state;
    }

    if ([domain isEqualToString:@"cover"]) {
        NSDictionary *names = @{
            @"open": @"Aperta", @"closed": @"Chiusa",
            @"opening": @"In apertura", @"closing": @"In chiusura"
        };
        NSNumber *position = attrs[@"current_position"];
        if ([position isKindOfClass:[NSNumber class]] &&
            [state isEqualToString:@"open"] &&
            position.integerValue < 100) {
            return [NSString stringWithFormat:@"Aperta · %ld%%",
                (long)position.integerValue];
        }
        return names[state] ?: state;
    }

    if ([domain isEqualToString:@"climate"]) {
        NSDictionary *names = @{
            @"off": @"Spento", @"heat": @"Riscaldamento",
            @"cool": @"Raffreddamento", @"auto": @"Automatico",
            @"heat_cool": @"Caldo/Freddo", @"dry": @"Deumidificazione",
            @"fan_only": @"Solo ventilazione"
        };
        NSString *mode = names[state] ?: state;
        NSNumber *current = attrs[@"current_temperature"];
        if ([current isKindOfClass:[NSNumber class]]) {
            return [NSString stringWithFormat:@"%@ · %@ °",
                mode, NEFormatNumber(current.doubleValue, 1)];
        }
        return mode;
    }

    if ([domain isEqualToString:@"media_player"]) {
        NSDictionary *names = @{
            @"off": @"Spento", @"on": @"Acceso", @"idle": @"Inattivo",
            @"playing": @"In riproduzione", @"paused": @"In pausa",
            @"standby": @"Standby", @"buffering": @"Caricamento"
        };
        NSString *title = NEString(attrs[@"media_title"]);
        if ([state isEqualToString:@"playing"] && title.length) return title;
        return names[state] ?: state;
    }

    if ([domain isEqualToString:@"vacuum"]) {
        NSDictionary *names = @{
            @"cleaning": @"In pulizia", @"docked": @"In base",
            @"returning": @"Rientro alla base", @"idle": @"Inattivo",
            @"paused": @"In pausa", @"error": @"Errore"
        };
        return names[state] ?: state;
    }

    if ([domain isEqualToString:@"lock"]) {
        NSDictionary *names = @{
            @"locked": @"Bloccata", @"unlocked": @"Sbloccata",
            @"locking": @"Blocco…", @"unlocking": @"Sblocco…",
            @"jammed": @"Inceppata", @"open": @"Aperta"
        };
        return names[state] ?: state;
    }

    if ([domain isEqualToString:@"weather"]) {
        NSString *condition = NEWeatherConditionText(state);
        NSNumber *temperature = attrs[@"temperature"];
        NSString *unit = NEString(attrs[@"temperature_unit"]) ?: @"°";
        if ([temperature isKindOfClass:[NSNumber class]]) {
            return [NSString stringWithFormat:@"%@ · %@ %@",
                condition, NEFormatNumber(temperature.doubleValue, 1), unit];
        }
        return condition;
    }

    if ([domain isEqualToString:@"sun"]) {
        return [state isEqualToString:@"above_horizon"]
            ? @"Sopra l'orizzonte" : @"Sotto l'orizzonte";
    }

    if ([domain isEqualToString:@"scene"] ||
        [domain isEqualToString:@"button"] ||
        [domain isEqualToString:@"input_button"]) {
        NSString *relative = NERelativeTime(state);
        return relative ? [@"Ultimo uso: " stringByAppendingString:relative]
                        : @"Mai usato";
    }

    if ([domain isEqualToString:@"script"]) {
        return on ? @"In esecuzione" : @"Pronto";
    }

    if ([domain isEqualToString:@"update"]) {
        return on ? @"Aggiornamento disponibile" : @"Aggiornato";
    }

    // Sensori: timestamp, numeri con unità e precisione.
    if ([dc isEqualToString:@"timestamp"] ||
        [dc isEqualToString:@"date"]) {
        NSString *relative = NERelativeTime(state);
        if (relative) return relative;
    }

    NSString *unit = NEString(attrs[@"unit_of_measurement"]);

    NSScanner *scanner = [NSScanner scannerWithString:state];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double number = 0;

    if ([scanner scanDouble:&number] && scanner.isAtEnd &&
        isfinite(number)) {
        NSInteger precision = -1;
        id saved = registry[@"precision"];
        if ([saved isKindOfClass:[NSNumber class]]) {
            precision = [saved integerValue];
        } else {
            NSRange dot = [state rangeOfString:@"."];
            precision = dot.location == NSNotFound
                ? 0 : MIN(2, (NSInteger)(state.length - dot.location - 1));
        }

        NSString *formatted = NEFormatNumber(number, precision);
        if (!unit.length) return formatted;
        if ([unit isEqualToString:@"%"])
            return [formatted stringByAppendingString:@" %"];
        return [NSString stringWithFormat:@"%@ %@", formatted, unit];
    }

    if (unit.length) return [NSString stringWithFormat:@"%@ %@", state, unit];

    if ([state isEqualToString:@"on"]) return @"Acceso";
    if ([state isEqualToString:@"off"]) return @"Spento";

    return state;
}

NSString *NEDomainTitle(NSString *domain) {
    NSDictionary *names = @{
        @"light": @"Luci",
        @"switch": @"Interruttori",
        @"input_boolean": @"Interruttori virtuali",
        @"fan": @"Ventilatori",
        @"cover": @"Tapparelle e tende",
        @"climate": @"Clima",
        @"media_player": @"Lettori multimediali",
        @"vacuum": @"Robot aspirapolvere",
        @"lock": @"Serrature",
        @"sensor": @"Sensori",
        @"binary_sensor": @"Sensori binari",
        @"scene": @"Scene",
        @"script": @"Script",
        @"button": @"Pulsanti",
        @"humidifier": @"Umidificatori",
        @"water_heater": @"Scaldacqua",
        @"weather": @"Meteo",
        @"person": @"Persone",
        @"number": @"Numeri",
        @"input_number": @"Numeri",
        @"select": @"Selezioni",
        @"input_select": @"Selezioni"
    };
    return names[domain] ?: domain;
}

NSInteger NEDomainOrder(NSString *domain) {
    NSArray *order = @[
        @"light", @"switch", @"fan", @"cover", @"climate",
        @"media_player", @"vacuum", @"lock", @"humidifier",
        @"water_heater", @"input_boolean", @"scene", @"script",
        @"button", @"number", @"input_number", @"select",
        @"input_select", @"sensor", @"binary_sensor"
    ];
    NSUInteger index = [order indexOfObject:domain ?: @""];
    return index == NSNotFound ? 999 : (NSInteger)index;
}
