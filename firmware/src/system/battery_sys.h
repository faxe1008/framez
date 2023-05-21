#ifndef FRAMEZ_BATTERY_SYS_H
#define FRAMEZ_BATTERY_SYS_H

int battery_sys_init(void);

int battery_sys_sample(uint8_t* battery_level);

#endif