#import <Foundation/Foundation.h>

/*
 * Optional machine-local configuration.
 *
 * Copy NineLocalConfig.user.h.example to NineLocalConfig.user.h and
 * customize it locally. The user file is ignored by Git and must never
 * contain access tokens or other credentials.
 */
#if __has_include("NineLocalConfig.user.h")
#import "NineLocalConfig.user.h"
#endif

#ifndef NINEHA_NAS_SWITCH_ENTITY
#define NINEHA_NAS_SWITCH_ENTITY @""
#endif

#ifndef NINEHA_NAS_STATUS_ENTITY
#define NINEHA_NAS_STATUS_ENTITY @""
#endif

#ifndef NINEHA_NAS_VM_STATUS_ENTITY
#define NINEHA_NAS_VM_STATUS_ENTITY @""
#endif

#ifndef NINEHA_SAFE_SWITCH_ENTITIES
#define NINEHA_SAFE_SWITCH_ENTITIES @[]
#endif

#ifndef NINEHA_NAS_GRACEFUL_ACTION
#define NINEHA_NAS_GRACEFUL_ACTION @""
#endif

#ifndef NINEHA_NAS_GRACEFUL_DOMAIN
#define NINEHA_NAS_GRACEFUL_DOMAIN @"script"
#endif

#ifndef NINEHA_NAS_GRACEFUL_SERVICE
#define NINEHA_NAS_GRACEFUL_SERVICE @""
#endif

#ifndef NINEHA_NAS_FORCE_ACTION
#define NINEHA_NAS_FORCE_ACTION @""
#endif

#ifndef NINEHA_NAS_FORCE_DOMAIN
#define NINEHA_NAS_FORCE_DOMAIN @"rest_command"
#endif

#ifndef NINEHA_NAS_FORCE_SERVICE
#define NINEHA_NAS_FORCE_SERVICE @""
#endif
