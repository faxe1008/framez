#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include "battery_sys.h"
LOG_MODULE_REGISTER(app);

void main(void)
{
    uint8_t level;

    battery_sys_init();
    battery_sys_sample(&level);
    LOG_INF("Battery Level: %u", level);


}
