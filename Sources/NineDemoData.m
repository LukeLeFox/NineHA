#import "NineDemoData.h"

#ifdef NINEHA_DEMO

static NSString *NDAgo(NSTimeInterval seconds) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'+00:00'";
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-seconds]];
}

static NSDictionary *NDEntity(NSString *entityID, NSString *state,
                              NSDictionary *attributes, NSTimeInterval ago) {
    return @{
        @"entity_id": entityID,
        @"state": state,
        @"attributes": attributes ?: @{},
        @"last_changed": NDAgo(ago),
        @"last_updated": NDAgo(ago)
    };
}

@implementation NineDemoData

+ (NSString *)serverURL { return @"http://192.0.2.20:8123"; }
+ (NSString *)locationName { return @"Casa Demo"; }

+ (NSArray *)areaNames {
    return @[@"Soggiorno", @"Cucina", @"Camera da letto", @"Studio", @"Bagno"];
}

+ (NSDictionary *)areaIcons {
    return @{
        @"Soggiorno": @"mdi:sofa",
        @"Cucina": @"mdi:stove",
        @"Camera da letto": @"mdi:bed",
        @"Studio": @"mdi:desk",
        @"Bagno": @"mdi:shower"
    };
}

+ (NSArray *)states {
    NSDictionary *dimmable = @{@"supported_color_modes": @[@"brightness"]};

    NSMutableDictionary *(^light)(NSString *, NSInteger) =
        ^NSMutableDictionary *(NSString *name, NSInteger brightness) {
        NSMutableDictionary *attrs = [dimmable mutableCopy];
        attrs[@"friendly_name"] = name;
        if (brightness > 0) attrs[@"brightness"] = @(brightness);
        return attrs;
    };

    return @[
        NDEntity(@"weather.casa", @"partlycloudy", @{
            @"friendly_name": @"Meteo casa", @"temperature": @18.4,
            @"temperature_unit": @"°C", @"humidity": @72,
            @"pressure": @1014.2, @"pressure_unit": @"hPa",
            @"wind_speed": @9.3, @"wind_speed_unit": @"km/h"}, 1800),
        NDEntity(@"person.anna", @"home", @{@"friendly_name": @"Anna"}, 7200),
        NDEntity(@"person.marco", @"not_home", @{@"friendly_name": @"Marco"}, 5400),

        // Soggiorno
        NDEntity(@"light.soggiorno_lampadario", @"on",
                 light(@"Lampadario", 191), 900),
        NDEntity(@"light.soggiorno_piantana", @"off",
                 light(@"Piantana", 0), 14400),
        NDEntity(@"light.soggiorno_led_tv", @"on",
                 light(@"LED TV", 102), 2400),
        NDEntity(@"switch.soggiorno_presa_tv", @"on", @{
            @"friendly_name": @"Presa TV", @"device_class": @"outlet"}, 9000),
        NDEntity(@"media_player.soggiorno_tv", @"playing", @{
            @"friendly_name": @"TV Soggiorno", @"device_class": @"tv",
            @"media_title": @"Telegiornale"}, 1200),
        NDEntity(@"cover.soggiorno_tapparella", @"open", @{
            @"friendly_name": @"Tapparella", @"device_class": @"shutter",
            @"current_position": @60, @"supported_features": @15}, 3600),
        NDEntity(@"sensor.soggiorno_temperatura", @"21.43", @{
            @"friendly_name": @"Temperatura soggiorno",
            @"device_class": @"temperature",
            @"unit_of_measurement": @"°C"}, 300),
        NDEntity(@"sensor.soggiorno_umidita", @"48", @{
            @"friendly_name": @"Umidità soggiorno",
            @"device_class": @"humidity",
            @"unit_of_measurement": @"%"}, 600),
        NDEntity(@"binary_sensor.soggiorno_finestra", @"off", @{
            @"friendly_name": @"Finestra soggiorno",
            @"device_class": @"window"}, 20000),

        // Cucina
        NDEntity(@"light.cucina_isola", @"on",
                 light(@"Isola", 255), 1500),
        NDEntity(@"light.cucina_pensili", @"off",
                 light(@"Pensili", 0), 30000),
        NDEntity(@"switch.cucina_macchina_caffe", @"off", @{
            @"friendly_name": @"Macchina del caffè"}, 16000),
        NDEntity(@"sensor.cucina_temperatura", @"22.08", @{
            @"friendly_name": @"Temperatura cucina",
            @"device_class": @"temperature",
            @"unit_of_measurement": @"°C"}, 400),
        NDEntity(@"binary_sensor.cucina_fumo", @"off", @{
            @"friendly_name": @"Rilevatore fumo",
            @"device_class": @"smoke"}, 86400),
        NDEntity(@"sensor.cucina_frigo_potenza", @"86", @{
            @"friendly_name": @"Frigorifero potenza",
            @"device_class": @"power",
            @"unit_of_measurement": @"W"}, 60),

        // Camera da letto
        NDEntity(@"light.camera_comodino_anna", @"off",
                 light(@"Comodino Anna", 0), 40000),
        NDEntity(@"light.camera_comodino_marco", @"off",
                 light(@"Comodino Marco", 0), 41000),
        NDEntity(@"climate.camera", @"heat", @{
            @"friendly_name": @"Termostato camera",
            @"current_temperature": @19.2, @"temperature": @20.5,
            @"min_temp": @7, @"max_temp": @30, @"target_temp_step": @0.5,
            @"supported_features": @1}, 5000),
        NDEntity(@"cover.camera_tenda", @"closed", @{
            @"friendly_name": @"Tenda", @"device_class": @"curtain",
            @"supported_features": @3}, 30000),
        NDEntity(@"sensor.camera_temperatura", @"19.24", @{
            @"friendly_name": @"Temperatura camera",
            @"device_class": @"temperature",
            @"unit_of_measurement": @"°C"}, 500),

        // Studio
        NDEntity(@"switch.example_nas", @"unavailable", @{
            @"friendly_name": @"NAS"}, 3000),
        NDEntity(@"binary_sensor.example_nas_online", @"on", @{
            @"friendly_name": @"NAS online",
            @"device_class": @"connectivity"}, 3000),
        NDEntity(@"binary_sensor.example_vm_running", @"on", @{
            @"friendly_name": @"VM NAS",
            @"device_class": @"running"}, 3300),
        NDEntity(@"light.studio_scrivania", @"on",
                 light(@"Lampada scrivania", 153), 2000),
        NDEntity(@"switch.studio_monitor", @"on", @{
            @"friendly_name": @"Monitor"}, 2100),
        NDEntity(@"fan.studio_ventilatore", @"off", @{
            @"friendly_name": @"Ventilatore"}, 50000),
        NDEntity(@"sensor.studio_co2", @"612", @{
            @"friendly_name": @"CO₂ studio",
            @"device_class": @"carbon_dioxide",
            @"unit_of_measurement": @"ppm"}, 120),
        NDEntity(@"sensor.studio_ups_batteria", @"100", @{
            @"friendly_name": @"UPS batteria",
            @"device_class": @"battery",
            @"unit_of_measurement": @"%"}, 9000),
        NDEntity(@"button.studio_accendi_pc", NDAgo(172800), @{
            @"friendly_name": @"Accendi PC",
            @"icon": @"mdi:desktop-tower-monitor"}, 172800),

        // Bagno
        NDEntity(@"light.bagno", @"off", light(@"Luce bagno", 0), 6000),
        NDEntity(@"sensor.bagno_umidita", @"64", @{
            @"friendly_name": @"Umidità bagno",
            @"device_class": @"humidity",
            @"unit_of_measurement": @"%"}, 700),
        NDEntity(@"binary_sensor.bagno_movimento", @"on", @{
            @"friendly_name": @"Movimento bagno",
            @"device_class": @"motion"}, 90),

        // Senza stanza
        NDEntity(@"light.giardino", @"off", light(@"Luci giardino", 0), 60000),
        NDEntity(@"vacuum.robot", @"docked", @{
            @"friendly_name": @"Robot aspirapolvere"}, 10000),
        NDEntity(@"scene.serata_film", NDAgo(90000), @{
            @"friendly_name": @"Serata film"}, 90000)
    ];
}

+ (NSDictionary *)entityAreas {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSDictionary *prefixes = @{
        @"soggiorno": @"Soggiorno",
        @"cucina": @"Cucina",
        @"camera": @"Camera da letto",
        @"studio": @"Studio",
        @"bagno": @"Bagno"
    };

    for (NSDictionary *entity in [self states]) {
        NSString *entityID = entity[@"entity_id"];
        NSString *object = [[entityID componentsSeparatedByString:@"."] lastObject];

        for (NSString *prefix in prefixes) {
            if ([object hasPrefix:prefix]) map[entityID] = prefixes[prefix];
        }
    }

    map[@"binary_sensor.example_nas_online"] = @"Studio";
    map[@"binary_sensor.example_vm_running"] = @"Studio";
    return map;
}

+ (NSDictionary *)registry {
    NSMutableDictionary *registry = [NSMutableDictionary dictionary];
    NSDictionary *areas = [self entityAreas];

    for (NSDictionary *entity in [self states]) {
        NSString *entityID = entity[@"entity_id"];
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        if (areas[entityID]) info[@"area"] = areas[entityID];
        if ([entityID hasPrefix:@"sensor."] &&
            [entityID rangeOfString:@"temperatura"].location != NSNotFound) {
            info[@"precision"] = @1;
        }
        registry[entityID] = info;
    }

    return registry;
}

@end

#endif
