/******************************************************************************
* File Name:   nec_tranmitter.h
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
#if !defined(NECTRANSMITTER_H)
#define NECTRANSMITTER_H

#include "cyhal.h"
#include "cybsp.h"

/***************************Macro Declarations*******************************/
#define NEC_IR_OUTPUT_PIN                           (P0_2) /* IO0 */
#define NEC_IR_OUTPUT_COMPL_PIN                     (P0_3) /* IO1 */
#define NEC_IR_OUTPUT_ACTIVE_HIGH_ENABLE            (1u)


#define NEC_TIMER_FREQUENCY_HZ                      (1000000UL) /* 1 MHz */
#define NEC_TIMER_INTERRUPT_TYPE                    CYHAL_TIMER_IRQ_TERMINAL_COUNT
#define NEC_TIMER_INTERRUPT_PRIORITY                3u

#define NEC_PULSE_FREQUENCY                         (38000u)    /* 38 kHz */
#define NEC_PULSE_DUTY_CYCLE                        (25u)       /* 25% or 33% */

#define NEC_LEADER_PULSE_TIME_US                    (9000u)
#define NEC_LEADER_IDLE_TIME_US                     (4500u)

#define NEC_INTERMEDIATE_PULSE_TIME_US              (560u)

#define NEC_BIT_1_IDLE_TIME_US                      (2250u - NEC_INTERMEDIATE_PULSE_TIME_US)
#define NEC_BIT_0_IDLE_TIME_US                      (1120u - NEC_INTERMEDIATE_PULSE_TIME_US)

#define NEC_REPEAT_INTERVAL_US                      (110000UL)

#define NEC_REPEAT_PULSE_TIME_US                    (9000u)
#define NEC_REPEAT_IDLE_TIME_US                     (2250u)

#define FAN_MODEL_ORIENT                            (1)
#define FAN_MODEL_GORILLA                           (2)

#define FAN_MODEL                                   FAN_MODEL_GORILLA


#define NEC_CODE_GORILLA_FAN_POWER_ADDRESS          (0xF300)
#define NEC_CODE_GORILLA_FAN_POWER_COMMAND          (0x91)
#define NEC_CODE_GORILLA_FAN_LIGHT_ADDRESS          (0xF300)
#define NEC_CODE_GORILLA_FAN_LIGHT_COMMAND          (0x97)
#define NEC_CODE_GORILLA_FAN_SPEED_UP_ADDRESS       (0xF300)
#define NEC_CODE_GORILLA_FAN_SPEED_UP_COMMAND       (0x94)
#define NEC_CODE_GORILLA_FAN_SPEED_DOWN_ADDRESS     (0xF300)
#define NEC_CODE_GORILLA_FAN_SPEED_DOWN_COMMAND     (0x95)
#define NEC_CODE_GORILLA_FAN_BOOST_ADDRESS          (0xF300)
#define NEC_CODE_GORILLA_FAN_BOOST_COMMAND          (0x8F)
#define NEC_CODE_GORILLA_FAN_TIMER_ADDRESS          (0xF300)
#define NEC_CODE_GORILLA_FAN_TIMER_COMMAND          (0x96)
#define NEC_CODE_GORILLA_FAN_SLEEP_ADDRESS          (0xF300)
#define NEC_CODE_GORILLA_FAN_SLEEP_COMMAND          (0x8E)

#define NEC_CODE_REPEAT_COUNT                       (1u)


/****************************************************************************/

/**************************Function Declarations*****************************/
cy_rslt_t nec_timer_init(void);
void send_nec_code(uint16_t address, uint16_t command, int8_t num_repeats);
/****************************************************************************/

#endif /* #include NECTRANSMITTER_H */
/* [] END OF FILE */
