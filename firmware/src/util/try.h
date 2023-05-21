#ifndef FRAMEZ_UTIL_TRY_H
#define FRAMEZ_UTIL_TRY_H

#define TRY(expression) \
    ({                         \
        int rc = (expression); \
        if (rc < 0)           \
                return rc; })

#endif