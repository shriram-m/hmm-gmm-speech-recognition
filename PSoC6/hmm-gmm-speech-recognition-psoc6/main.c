/******************************************************************************
* File Name:   main.c
*
* Description: This is the source code for HMM-GMM based Speech Recognition system.
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

#include "cyhal.h"
#include "cybsp.h"
#include "cy_retarget_io.h"

#include "hmm_gmm_speech_recognition_lib.h"

#include "nec_transmitter.h"


/*******************************************************************************
* Macros
*******************************************************************************/
#define FRAME_SIZE                  (16000u)
#define SAMPLE_RATE_HZ              (16000u)
#define DECIMATION_RATE             (96u)
#define AUDIO_SYS_CLOCK_HZ          (24576000u)
#define PDM_DATA                    (P10_5)
#define PDM_CLK                     (P10_4)

#define NUM_KEYWORDS                (5u)

/*******************************************************************************
* Function Prototypes
*******************************************************************************/
void pdm_pcm_isr_handler(void *arg, cyhal_pdm_pcm_event_t event);
void clock_init(void);

/*******************************************************************************
* Global Variables
*******************************************************************************/
volatile bool pdm_pcm_flag = false;
volatile bool wakeword_flag = false;

int16_t pdm_pcm_ping[FRAME_SIZE] = {0};
int16_t pdm_pcm_pong[FRAME_SIZE] = {0};

int16_t pdm_pcm_float_arr[FRAME_SIZE] = {0};

int16_t *pdm_pcm_buffer = &pdm_pcm_ping[0];
cyhal_pdm_pcm_t pdm_pcm;
cyhal_clock_t   audio_clock;
cyhal_clock_t   pll_clock;

const cyhal_pdm_pcm_cfg_t pdm_pcm_cfg = 
{
    .sample_rate     = SAMPLE_RATE_HZ,
    .decimation_rate = DECIMATION_RATE,
    .mode            = CYHAL_PDM_PCM_MODE_LEFT, 
    .word_length     = 16,  /* bits */
    .left_gain       = CYHAL_PDM_PCM_MAX_GAIN,   /* dB */
    .right_gain      = CYHAL_PDM_PCM_MAX_GAIN,   /* dB */
};

typedef enum
{
    WAKEWORD    = 101,
    ON          = 201,
    OFF         = 202,
    UP          = 203,
    DOWN        = 204,
} speech_commands_e;

static bool fan_power_on = false;
static bool fan_led_on = false;


/*******************************************************************************
* Function Name: main
********************************************************************************
* Summary:
* This is the main function.
*
* Parameters:
*  none
*
* Return:
*  int
*
*******************************************************************************/
int main(void)
{
    cy_rslt_t result;

    /* Initialize the device and board peripherals */
    result = cybsp_init();
    
    /* Board init failed. Stop program execution */
    if (result != CY_RSLT_SUCCESS)
    {
        CY_ASSERT(0);
    }

    /* Enable global interrupts */
    __enable_irq();

    /* Initialize the clocks for PDM/PCM audio */
    clock_init();

    /* Initialize the RED LED */
    cyhal_gpio_init(CYBSP_LED_RGB_RED, CYHAL_GPIO_DIR_OUTPUT, CYHAL_GPIO_DRIVE_STRONG, CYBSP_LED_STATE_OFF);

    /* Initialize retarget-io to use the debug UART port */
    result = cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX,
                                 CY_RETARGET_IO_BAUDRATE);

    /* retarget-io init failed. Stop program execution */
    if (result != CY_RSLT_SUCCESS)
    {
        CY_ASSERT(0);
    }

    cyhal_pdm_pcm_init(&pdm_pcm, PDM_DATA, PDM_CLK, &audio_clock, &pdm_pcm_cfg);
    cyhal_pdm_pcm_register_callback(&pdm_pcm, pdm_pcm_isr_handler, NULL);
    cyhal_pdm_pcm_enable_event(&pdm_pcm, CYHAL_PDM_PCM_ASYNC_COMPLETE, CYHAL_ISR_PRIORITY_DEFAULT, true);

    printf("\x1b[2J\x1b[;H");
    printf("================================================\r\n");
    printf(" HMM-HMM based Speech Recognition on PSoC 6 MCU\r\n");
    printf("================================================\r\n");

    /* Initialize the timers for NEC IR protocol */
    result = nec_timer_init();
    if(result != CY_RSLT_SUCCESS)
    {
        CY_ASSERT(0);
    }

    cyhal_pdm_pcm_start(&pdm_pcm);
    cyhal_pdm_pcm_read_async(&pdm_pcm, pdm_pcm_buffer, FRAME_SIZE);

    float fopt_array[NUM_KEYWORDS];
    float model_id;

    while(1)
    {
        if(pdm_pcm_flag)
        {
            pdm_pcm_flag = 0;
            for (uint32_t i = 0; i < FRAME_SIZE; i++)
            {
                pdm_pcm_float_arr[i] = pdm_pcm_buffer[i];
            }

            printf("Calling hmm_gmm_speech_recognition() ...\r\n");
            hmm_gmm_speech_recognition(pdm_pcm_float_arr, fopt_array, &model_id);
            printf("hmm_gmm_speech_recognition returned = %f\r\n\r\n", model_id);

            switch((int16_t)model_id)
            {
                case WAKEWORD:
                {
                    wakeword_flag = true;
                    cyhal_gpio_write(CYBSP_LED_RGB_RED, CYBSP_LED_STATE_ON);
                    break;
                }
                case ON:
                {
                    if (!fan_power_on && wakeword_flag)
                    {
                        fan_power_on = true;
                        #if (FAN_MODEL == FAN_MODEL_GORILLA)
                        send_nec_code(NEC_CODE_GORILLA_FAN_POWER_ADDRESS, NEC_CODE_GORILLA_FAN_POWER_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #else
                        send_nec_code(NEC_CODE_ORIENT_FAN_POWER_ADDRESS, NEC_CODE_ORIENT_FAN_POWER_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #endif
                        wakeword_flag = false;
                        cyhal_gpio_write(CYBSP_LED_RGB_RED, CYBSP_LED_STATE_OFF);
                    }
                    break;
                }
                case OFF:
                {
                    if (fan_power_on && wakeword_flag)
                    {
                        fan_power_on = false;
                        #if (FAN_MODEL == FAN_MODEL_GORILLA)
                        send_nec_code(NEC_CODE_GORILLA_FAN_POWER_ADDRESS, NEC_CODE_GORILLA_FAN_POWER_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #else
                        send_nec_code(NEC_CODE_ORIENT_FAN_POWER_ADDRESS, NEC_CODE_ORIENT_FAN_POWER_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #endif
                        wakeword_flag = false;
                        cyhal_gpio_write(CYBSP_LED_RGB_RED, CYBSP_LED_STATE_OFF);
                    }
                    break;
                }
                case UP:
                {
                    if (wakeword_flag)
                    {
                        #if (FAN_MODEL == FAN_MODEL_GORILLA)
                        send_nec_code(NEC_CODE_GORILLA_FAN_SPEED_UP_ADDRESS, NEC_CODE_GORILLA_FAN_SPEED_UP_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #else
                        send_nec_code(NEC_CODE_ORIENT_FAN_SPEED_UP_ADDRESS, NEC_CODE_ORIENT_FAN_SPEED_UP_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #endif
                        wakeword_flag = false;
                        cyhal_gpio_write(CYBSP_LED_RGB_RED, CYBSP_LED_STATE_OFF);
                    }
                    break;
                }
                case DOWN:
                {
                    if (wakeword_flag)
                    {
                        #if (FAN_MODEL == FAN_MODEL_GORILLA)
                        send_nec_code(NEC_CODE_GORILLA_FAN_SPEED_DOWN_ADDRESS, NEC_CODE_GORILLA_FAN_SPEED_DOWN_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #else
                        send_nec_code(NEC_CODE_ORIENT_FAN_SPEED_DOWN_ADDRESS, NEC_CODE_ORIENT_FAN_SPEED_DOWN_COMMAND, NEC_CODE_REPEAT_COUNT);
                        #endif
                        wakeword_flag = false;
                        cyhal_gpio_write(CYBSP_LED_RGB_RED, CYBSP_LED_STATE_OFF);
                    }
                    break;
                }
            }
        }
    }
}


void pdm_pcm_isr_handler(void *arg, cyhal_pdm_pcm_event_t event)
{
    static bool ping_pong = false;

    (void) arg;
    (void) event;

    if(ping_pong)
    {
        cyhal_pdm_pcm_read_async(&pdm_pcm, pdm_pcm_ping, FRAME_SIZE);
        pdm_pcm_buffer = &pdm_pcm_pong[0];
    }
    else
    {
        cyhal_pdm_pcm_read_async(&pdm_pcm, pdm_pcm_pong, FRAME_SIZE);
        pdm_pcm_buffer = &pdm_pcm_ping[0]; 
    }

    ping_pong = !ping_pong;
    pdm_pcm_flag = true;
}


void clock_init(void)
{
	cyhal_clock_reserve(&pll_clock, &CYHAL_CLOCK_PLL[0]);
    cyhal_clock_set_frequency(&pll_clock, AUDIO_SYS_CLOCK_HZ, NULL);
    cyhal_clock_set_enabled(&pll_clock, true, true);

    cyhal_clock_reserve(&audio_clock, &CYHAL_CLOCK_HF[1]);

    cyhal_clock_set_source(&audio_clock, &pll_clock);
    cyhal_clock_set_enabled(&audio_clock, true, true);
}

/* [] END OF FILE */
