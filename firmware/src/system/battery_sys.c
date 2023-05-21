#include "try.h"
#include <autoconf.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(battery_sys);

#if !DT_NODE_EXISTS(DT_PATH(zephyr_user)) || !DT_NODE_HAS_PROP(DT_PATH(zephyr_user), io_channels)
#    error "No suitable devicetree overlay specified"
#endif

static const struct adc_dt_spec battery_adc_spec = ADC_DT_SPEC_GET_BY_IDX(DT_PATH(zephyr_user), 0);
static const struct gpio_dt_spec battery_mos_gpio = GPIO_DT_SPEC_GET(DT_PATH(zephyr_user), battery_mos_gpios);

int battery_sys_init(void)
{
    if (!device_is_ready(battery_adc_spec.dev)) {
        return -EIO;
    }

    TRY(adc_channel_setup_dt(&battery_adc_spec));
    TRY(gpio_is_ready_dt(&battery_mos_gpio));

    return 0;
}

static uint8_t millivolts_to_battery_level(int32_t val_mv)
{
    uint32_t level = ((val_mv - CONFIG_BATTERY_VOLTAGE_MIN) * 100) / (CONFIG_BATTERY_VOLTAGE_MAX - CONFIG_BATTERY_VOLTAGE_MIN);
    if (level > 100) {
        return 100;
    }
    return level;
}

int battery_sys_sample(uint8_t* battery_level)
{
    int rc;
    uint16_t buf[CONFIG_BATTERY_VOLTAGE_EXTRA_SAMPLING_COUNT + 1] = {0};
    int32_t val_mv = 0;
    int32_t battery_mos_level;

    struct adc_sequence_options options = {
        .interval_us = CONFIG_BATTERY_VOLTAGE_SAMPLING_INTERVAL,
        .extra_samplings = CONFIG_BATTERY_VOLTAGE_EXTRA_SAMPLING_COUNT
    };
    struct adc_sequence sequence = {
        .buffer = &buf,
        .buffer_size = sizeof(buf),
        .options = &options
    };

    // Turn on the battery mosfet
    TRY(gpio_pin_configure_dt(&battery_mos_gpio, GPIO_INPUT));
    battery_mos_level = gpio_pin_get_dt(&battery_mos_gpio);
    if (battery_mos_level < 0) {
        return battery_mos_level;
    }
    TRY(gpio_pin_configure_dt(&battery_mos_gpio, GPIO_OUTPUT_ACTIVE));

    if(battery_mos_level){
        TRY(gpio_pin_set_dt(&battery_mos_gpio, 0));
    }else{
        TRY(gpio_pin_set_dt(&battery_mos_gpio, 1));
    }
    k_sleep(K_MSEC(5));


    TRY(adc_sequence_init_dt(&battery_adc_spec, &sequence));
    TRY(adc_read(battery_adc_spec.dev, &sequence));

    for (int i = 0; i < CONFIG_BATTERY_VOLTAGE_EXTRA_SAMPLING_COUNT + 1; i++) {
        if (battery_adc_spec.channel_cfg.differential) {
            val_mv += ((int32_t)((int16_t)buf[i])) *2;
        } else {
            val_mv += ((int32_t)buf[i]) * 2;
        }
    }
    val_mv /= (CONFIG_BATTERY_VOLTAGE_EXTRA_SAMPLING_COUNT + 1);

    TRY(adc_raw_to_millivolts_dt(&battery_adc_spec, &val_mv));

    LOG_ERR("Voltage %i", val_mv);
    *battery_level = millivolts_to_battery_level(val_mv);

    // Turn of the battery mosfet
    if(battery_mos_level){
        TRY(gpio_pin_set_dt(&battery_mos_gpio, 1));
    }else{
        TRY(gpio_pin_set_dt(&battery_mos_gpio, 0));
    }

    return 0;
}