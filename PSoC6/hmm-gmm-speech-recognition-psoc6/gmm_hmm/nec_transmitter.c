/******************************************************************************
* File Name:   nec_tranmitter.c
*
* Description: This is the source code for NEC IR transmitter APIs.
*
* Related Document: See README.md
*
*
*******************************************************************************
* Copyright 2022-2023, Cypress Semiconductor Corporation (an Infineon company) or
* an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
*
* This software, including source code, documentation and related
* materials ("Software") is owned by Cypress Semiconductor Corporation
* or one of its affiliates ("Cypress") and is protected by and subject to
* worldwide patent protection (United States and foreign),
* United States copyright laws and international treaty provisions.
* Therefore, you may use this Software only as provided in the license
* agreement accompanying the software package from which you
* obtained this Software ("EULA").
* If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
* non-transferable license to copy, modify, and compile the Software
* source code solely for use in connection with Cypress's
* integrated circuit products.  Any reproduction, modification, translation,
* compilation, or representation of this Software except as specified
* above is prohibited without the express written permission of Cypress.
*
* Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
* reserves the right to make changes to the Software without notice. Cypress
* does not assume any liability arising out of the application or use of the
* Software or any product or circuit described in the Software. Cypress does
* not authorize its products for use in any products where a malfunction or
* failure of the Cypress product may reasonably be expected to result in
* significant property damage, injury or death ("High Risk Product"). By
* including Cypress's product in a High Risk Product, the manufacturer
* of such system or application assumes all risk of such use and in doing
* so agrees to indemnify Cypress against all liability.
*******************************************************************************/
#include "nec_transmitter.h"

#include "cyhal_tcpwm_common.h"

#include "cyhal.h"
#include "cybsp.h"

/****************************************************************************/

/**************************Variable Declarations*****************************/
static cyhal_timer_cfg_t pulse_timer_cfg =
{
    .compare_value = 0,                                                             // Timer compare value, not used
    .period        = NEC_INTERMEDIATE_PULSE_TIME_US,  /* Modifiable */       // Defines the timer period
    .direction     = CYHAL_TIMER_DIR_UP,                                            // Timer counts up
    .is_compare    = false,                                                         // Don't use compare mode
    .is_continuous = false,                                                         // Run the timer indefinitely
    .value         = 0                                                              // Initial value of counter
};

static cyhal_timer_cfg_t idle_timer_cfg =
{
    .compare_value = 0,                                             // Timer compare value, not used
    .period        = NEC_LEADER_IDLE_TIME_US,   /* Modifiable */    // Defines the timer period
    .direction     = CYHAL_TIMER_DIR_UP,                            // Timer counts up
    .is_compare    = false,                                         // Don't use compare mode
    .is_continuous = false,                                         // Run the timer indefinitely
    .value         = 0                                              // Initial value of counter
};


static volatile bool nec_tx_complete = true;

static cyhal_timer_t    pulse_timer_obj;    /* Either 560 us or 9000us for leader only */
static cyhal_timer_t    idle_timer_obj;     /* Depends on leader / Bit0 / Bit1 */
static cyhal_pwm_t      pwm_obj;

/* Struct to store the pulse and idle times for each bit */
typedef struct
{
    int32_t pulse_period;
    int32_t idle_period;
} bit_info_t;

static bit_info_t bit_info[100] = {0};
static uint32_t current_bit_index = 0;

/****************************************************************************/
static void isr_pulse_timer(void* callback_arg, cyhal_timer_event_t event);
static void isr_idle_timer(void* callback_arg, cyhal_timer_event_t event);


/******************************************************************************
* Function Name: nec_timer_init
*******************************************************************************
* Summary:
*       
*
* Parameters:
*  
*
* Return:
*  
*
*******************************************************************************/
cy_rslt_t nec_timer_init(void)
{
    cy_rslt_t result;

    result = cyhal_pwm_init_adv(&pwm_obj, NEC_IR_OUTPUT_PIN, NEC_IR_OUTPUT_COMPL_PIN, CYHAL_PWM_LEFT_ALIGN, true, 0u, false, NULL);
    CY_ASSERT(CY_RSLT_SUCCESS == result);
 
    result = cyhal_pwm_set_duty_cycle(&pwm_obj, NEC_PULSE_DUTY_CYCLE, NEC_PULSE_FREQUENCY);
    CY_ASSERT(CY_RSLT_SUCCESS == result);



    result = cyhal_timer_init(&pulse_timer_obj, NC, NULL);
    CY_ASSERT(CY_RSLT_SUCCESS == result);

    result = cyhal_timer_configure(&pulse_timer_obj, &pulse_timer_cfg);
    CY_ASSERT(CY_RSLT_SUCCESS == result);

    result = cyhal_timer_set_frequency(&pulse_timer_obj, NEC_TIMER_FREQUENCY_HZ);
    CY_ASSERT(CY_RSLT_SUCCESS == result);

    cyhal_timer_register_callback(&pulse_timer_obj, isr_pulse_timer, NULL);
    cyhal_timer_enable_event(&pulse_timer_obj, NEC_TIMER_INTERRUPT_TYPE, NEC_TIMER_INTERRUPT_PRIORITY, true);



    result = cyhal_timer_init(&idle_timer_obj, NC, NULL);
    CY_ASSERT(CY_RSLT_SUCCESS == result);

    result = cyhal_timer_configure(&idle_timer_obj, &idle_timer_cfg);
    CY_ASSERT(CY_RSLT_SUCCESS == result);

    result = cyhal_timer_set_frequency(&idle_timer_obj, NEC_TIMER_FREQUENCY_HZ);
    CY_ASSERT(CY_RSLT_SUCCESS == result);

    cyhal_timer_register_callback(&idle_timer_obj, isr_idle_timer, NULL);
    cyhal_timer_enable_event(&idle_timer_obj, NEC_TIMER_INTERRUPT_TYPE, NEC_TIMER_INTERRUPT_PRIORITY, true);


    return result;
}

/******************************************************************************
* Function Name: send_nec_code
*******************************************************************************
* Summary:
*       
*
* Parameters:
*  
*
* Return:
*  void
*
*******************************************************************************/
void send_nec_code(uint16_t address, uint16_t command, int8_t num_repeats)
{
    /* Update the nec_tx_complete to indicate busy status */
    nec_tx_complete = false;

    uint32_t bit_index = 0, i, remaining_idle_time = NEC_REPEAT_INTERVAL_US;
    uint16_t temp_address, temp_command;
    uint8_t  bit;

    /* Setup the bit_info array based on received address and command */

    /* Leader info */
    bit_info[bit_index].pulse_period = NEC_LEADER_PULSE_TIME_US;
    bit_info[bit_index].idle_period = NEC_LEADER_IDLE_TIME_US;
    remaining_idle_time -= (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
    bit_index ++;

    /* Address */
    temp_address = address;
    for (i = 0; i < 16; i++)
    {
        bit = temp_address & 0x0001;
        
        bit_info[bit_index].pulse_period = NEC_INTERMEDIATE_PULSE_TIME_US;
        bit_info[bit_index].idle_period = (bit == 0) ? NEC_BIT_0_IDLE_TIME_US : NEC_BIT_1_IDLE_TIME_US;
        remaining_idle_time -= (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
        bit_index ++;

        temp_address = temp_address >> 1;
    }

    /* Command */
    temp_command = command;
    for (i = 0; i < 8; i++)
    {
        bit = temp_command & 0x0001;
        
        bit_info[bit_index].pulse_period = NEC_INTERMEDIATE_PULSE_TIME_US;
        bit_info[bit_index].idle_period = (bit == 0) ? NEC_BIT_0_IDLE_TIME_US : NEC_BIT_1_IDLE_TIME_US;
        remaining_idle_time -= (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
        bit_index ++;

        temp_command = temp_command >> 1;
    }

    /* ~Command */
    temp_command = command;
    for (i = 0; i < 8; i++)
    {
        bit = temp_command & 0x0001;
        
        bit_info[bit_index].pulse_period = NEC_INTERMEDIATE_PULSE_TIME_US;
        bit_info[bit_index].idle_period = (bit == 1) ? NEC_BIT_0_IDLE_TIME_US : NEC_BIT_1_IDLE_TIME_US;
        remaining_idle_time -= (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
        bit_index ++;

        temp_command = temp_command >> 1;
    }

    /* End */
    bit_info[bit_index].pulse_period = NEC_INTERMEDIATE_PULSE_TIME_US;
    bit_info[bit_index].idle_period = 0;
    remaining_idle_time -= (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
    bit_index ++;

    // printf("remaining_idle_time = %ld\r\n", remaining_idle_time);


    while (num_repeats > 0)
    {
        bit_info[bit_index - 1].idle_period = remaining_idle_time;
        bit_info[bit_index].pulse_period = NEC_REPEAT_PULSE_TIME_US;
        bit_info[bit_index].idle_period = NEC_REPEAT_IDLE_TIME_US;
        remaining_idle_time = NEC_REPEAT_INTERVAL_US - (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
        bit_index ++;

        bit_info[bit_index].pulse_period = NEC_INTERMEDIATE_PULSE_TIME_US;
        bit_info[bit_index].idle_period = 0;
        remaining_idle_time -= (bit_info[bit_index].pulse_period + bit_info[bit_index].idle_period);
        bit_index ++;

        num_repeats --;
    }

    // for (i = 0; i < bit_index; i++)
    // {
    //     printf("[%d]: %10ld | %10ld\r\n", i, bit_info[i].pulse_period, bit_info[i].idle_period);
    // }

    current_bit_index = 0;
    pulse_timer_cfg.period = (uint32_t) bit_info[current_bit_index].pulse_period;
    cyhal_timer_reset(&pulse_timer_obj);
    cyhal_timer_configure(&pulse_timer_obj, &pulse_timer_cfg);
    cyhal_timer_start(&pulse_timer_obj);

    cyhal_pwm_start(&pwm_obj);

    while (!nec_tx_complete)
    {
        cyhal_system_delay_ms(10);
    }
    printf("NEC IR TX Complete!\r\n");
}

/*******************************************************************************
* Function Name: isr_pulse_timer
********************************************************************************
* Summary:
*       
*
* Parameters:
*  
*
* Return:
*  void
*
*******************************************************************************/
static void isr_pulse_timer(void* callback_arg, cyhal_timer_event_t event)
{
    (void)callback_arg;
    (void)event;

    cyhal_pwm_stop(&pwm_obj);

    if (bit_info[current_bit_index].idle_period > 0)
    {
        idle_timer_cfg.period = (uint32_t) bit_info[current_bit_index].idle_period;
        cyhal_timer_reset(&idle_timer_obj);
        cyhal_timer_configure(&idle_timer_obj, &idle_timer_cfg);
        cyhal_timer_start(&idle_timer_obj);

        current_bit_index ++;
    }
    else
    {
        /* Done! */
        nec_tx_complete = true;
    }
}


/*******************************************************************************
* Function Name: isr_idle_timer
********************************************************************************
* Summary:
*       
*
* Parameters:
*  
*
* Return:
*  void
*
*******************************************************************************/
static void isr_idle_timer(void* callback_arg, cyhal_timer_event_t event)
{
    (void)callback_arg;
    (void)event;


    if (bit_info[current_bit_index].pulse_period > 0)
    {
        pulse_timer_cfg.period = (uint32_t) bit_info[current_bit_index].pulse_period;
        cyhal_timer_reset(&pulse_timer_obj);
        cyhal_timer_configure(&pulse_timer_obj, &pulse_timer_cfg);
        cyhal_timer_start(&pulse_timer_obj);

        cyhal_pwm_start(&pwm_obj);
    }
    else
    {
        /* Done! */
        nec_tx_complete = true;
    }
}

/* [] END OF FILE */
