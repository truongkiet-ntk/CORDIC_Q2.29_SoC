/*
 * source.c
 *
 *  Created on: May 29, 2026
 *      Author: pc
 */




#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <time.h>
#include "system.h"
#include "io.h"
#include "sys/alt_irq.h"
#include "alt_types.h"
#include "altera_avalon_sgdma.h"
#include "altera_avalon_sgdma_regs.h"
#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_pio_regs.h"
#include "sys/alt_stdio.h"
#define NUM_SAMPLES 32

enum {
	CORDIC_CTRL_OFFSET = 0x00,
	CORDIC_MODE_BIT = 1,
	CORDIC_MODE_ROTATION = 0x0u,
	CORDIC_MODE_VECTORING = 0x1u,
	PACKET_WORDS = 3,
	PACKET_BYTES = PACKET_WORDS * sizeof(alt_u32)
};

#ifndef SWITCHES_0_BASE
#define SWITCHES_0_BASE 0x13198u
#endif

#ifndef LEDS_0_BASE
#define LEDS_0_BASE 0x1319Cu
#endif

enum {
	LED_DONE_MASK = (1u << 0),
	LED_BUSY_MASK = (1u << 1),
	LED_ERROR_MASK = (1u << 15)
};

#define SW_MODE_MASK (1u << 0)
#define SW_START_MASK (1u << 1)

#define LCD_I2C_ADDR 0x27

typedef struct {
	char name[16];
	alt_u32 x_in;
	alt_u32 y_in;
	alt_u32 z_in;
} stream_case_t;

stream_case_t stream_cases[NUM_SAMPLES];
static alt_u32 used_angles[NUM_SAMPLES];
static int angle_exists(alt_u32 value, int count) {
	int i;
	for(i = 0; i < count; i++) {
		if(used_angles[i] == value) return 1;
	}
	return 0;
}
void generate_random_cases(void)
{
	int i;
	alt_u32 in_x;
	alt_u32 in_y;
	alt_u32 in_z;

	srand((unsigned int)time(NULL));
	for (i = 0; i < NUM_SAMPLES;i++){
		do{
			in_x = ((alt_u32)rand() << 16) ^ rand ();
			in_y = ((alt_u32)rand() << 16) ^ rand ();
			in_z = ((alt_u32)rand() << 16) ^ rand ();
			 // 0x00000000 -> 0
			// 0x40000000 -> 360
			in_z &= 0x3FFFFFFF;
		}
		while(angle_exists(in_z, i));

		used_angles[i] = in_z;

		snprintf(stream_cases[i].name, sizeof(stream_cases[i].name), "Case %d", i + 1);
		stream_cases[i].x_in = in_x;
		stream_cases[i].y_in = in_y;
		stream_cases[i].z_in = in_z;
	}

}


static alt_sgdma_descriptor tx_desc;
static alt_sgdma_descriptor tx_desc_next;
static alt_sgdma_descriptor rx_desc;
static alt_sgdma_descriptor rx_desc_next;
static alt_u32 tx_packet[PACKET_WORDS] __attribute__((aligned(32)));
static alt_u32 rx_packet_words[PACKET_WORDS] __attribute__((aligned(32)));
static volatile alt_u32 *const rx_packet = (volatile alt_u32 *)ONCHIP_MEMORY2_1_BASE;
static volatile alt_u32 start_flag = 0u;
static volatile alt_u32 tx_done_flag = 0u;
static volatile alt_u32 rx_done_flag = 0u;

typedef enum {
	APP_WAIT_START = 0,
	APP_RUNNING,
	APP_WAIT_DMA,
	APP_DONE,
	APP_ERROR
} app_state_t;

static void start_button_isr(void *context)
{
	(void)context;
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(START_BASE, 0x0);
	start_flag = 1u;
}

static void tx_dma_callback(void *context)
{
	(void)context;
	tx_done_flag = 1u;
}

static void rx_dma_callback(void *context)
{
	(void)context;
	rx_done_flag = 1u;
}

static void start_button_irq_init(void)
{
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(START_BASE, 0x0);
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(START_BASE, 0x1);
	alt_ic_isr_register(
		START_IRQ_INTERRUPT_CONTROLLER_ID,
		START_IRQ,
		start_button_isr,
		NULL,
		NULL);
}

static alt_u32 read_switches(void)
{
	return IORD_32DIRECT(SWITCHES_0_BASE, 0);
}

static void write_leds(alt_u32 value)
{
	IOWR_32DIRECT(LEDS_0_BASE, 0, value);
}

void delay_us(int us) { while (us-- > 0) { volatile int spin = 0; while (spin++ < 10) { } } }

void I2C_SCL_Write(int s) { IOWR(LCD_SCL_BASE, 0, s); }

void I2C_SDA_Write(int s) {
	if (s)
		IOWR(LCD_SDA_BASE, 1, 0);
	else {
		IOWR(LCD_SDA_BASE, 1, 1);
		IOWR(LCD_SDA_BASE, 0, 0);
	}
}

void I2C_Start() {
	I2C_SDA_Write(1); I2C_SCL_Write(1); delay_us(4);
	I2C_SDA_Write(0); delay_us(4);
	I2C_SCL_Write(0);
}

void I2C_Stop() {
	I2C_SDA_Write(0); delay_us(4);
	I2C_SCL_Write(1); delay_us(4);
	I2C_SDA_Write(1);
}

void I2C_SendByte(unsigned char d) {
	int i;
	for (i = 0; i < 8; i++) {
		I2C_SDA_Write((d & 0x80) ? 1 : 0);
		delay_us(2); I2C_SCL_Write(1); delay_us(4);
		I2C_SCL_Write(0); delay_us(2);
		d <<= 1;
	}
	I2C_SDA_Write(1);
	delay_us(2); I2C_SCL_Write(1); delay_us(4); I2C_SCL_Write(0);
}

void LCD_Write_Nibble(unsigned char n, unsigned char rs) {
	unsigned char d = n | (rs ? 0x01 : 0x00) | 0x08;
	I2C_Start();
	I2C_SendByte(LCD_I2C_ADDR << 1);
	I2C_SendByte(d | 0x04); delay_us(1);
	I2C_SendByte(d & ~0x04); delay_us(50);
	I2C_Stop();
}

void LCD_Send(unsigned char v, unsigned char mode) {
	LCD_Write_Nibble(v & 0xF0, mode);
	LCD_Write_Nibble((v << 4) & 0xF0, mode);
}

void LCD_Command(unsigned char c) { LCD_Send(c, 0); }
void LCD_Char(unsigned char c)    { LCD_Send(c, 1); }

void LCD_Init() {
	delay_us(50000);
	LCD_Write_Nibble(0x30, 0); delay_us(5000);
	LCD_Write_Nibble(0x30, 0); delay_us(200);
	LCD_Write_Nibble(0x30, 0); delay_us(200);
	LCD_Write_Nibble(0x20, 0); delay_us(200);
	LCD_Command(0x28); LCD_Command(0x0C);
	LCD_Command(0x06); LCD_Command(0x01);
	delay_us(2000);
}

void LCD_SetCursor(unsigned char row, unsigned char col) {
	LCD_Command((row == 0 ? 0x80 : 0xC0) + col);
}

void LCD_String(char *s) { while (*s) LCD_Char(*s++); }

static void lcd_show_waiting(void)
{
	LCD_SetCursor(0, 0);
	LCD_String("ACCULATOR CORDIC");
	LCD_SetCursor(1, 0);
	LCD_String("READY           ");
}

static void lcd_show_done(void)
{
	LCD_SetCursor(0, 0);
	LCD_String("CORDIC DONE     ");
	LCD_SetCursor(1, 0);
	LCD_String("WAITING......   ");
	usleep(800000);
}

static void lcd_show_error(void)
{
	LCD_SetCursor(0, 0);
	LCD_String("CORDIC ERROR    ");
	LCD_SetCursor(1, 0);
	LCD_String("WAITING......   ");
	usleep(800000);
}

static void lcd_show_case_outputs(unsigned int case_index)
{
	char buf[17];

	LCD_SetCursor(0, 0);
	snprintf(buf, sizeof(buf), "CASE %02u X      ", case_index + 1u);
	LCD_String(buf);
	LCD_SetCursor(1, 0);
	snprintf(buf, sizeof(buf), "%08lx      ", (unsigned long)rx_packet_words[0]);
	LCD_String(buf);
	usleep(200000);
	LCD_SetCursor(0, 0);
	snprintf(buf, sizeof(buf), "CASE %02u Y      ", case_index + 1u);
	LCD_String(buf);
	LCD_SetCursor(1, 0);
	snprintf(buf, sizeof(buf), "%08lx      ", (unsigned long)rx_packet_words[1]);
	LCD_String(buf);
	usleep(200000);
	LCD_SetCursor(0, 0);
	snprintf(buf, sizeof(buf), "CASE %02u Z      ", case_index + 1u);
	LCD_String(buf);
	LCD_SetCursor(1, 0);
	snprintf(buf, sizeof(buf), "%08lx      ", (unsigned long)rx_packet_words[2]);
	LCD_String(buf);
}

static alt_u32 swap_u32(alt_u32 value)
{
	return ((value & 0x000000FFu) << 24) |
		   ((value & 0x0000FF00u) << 😎 |
		   ((value & 0x00FF0000u) >> 😎 |
		   ((value & 0xFF000000u) >> 24);
}

static int start_case_dma(alt_sgdma_dev *tx_dev, alt_sgdma_dev *rx_dev, const stream_case_t *test_case, alt_u32 mode)
{
	int status;
	alt_u32 ctrl_value = (mode & 0x1u) << CORDIC_MODE_BIT;

	tx_done_flag = 0u;
	rx_done_flag = 0u;

	tx_packet[0] = test_case->x_in;
	tx_packet[1] = test_case->y_in;
	tx_packet[2] = test_case->z_in;
	tx_packet[0] = swap_u32(tx_packet[0]);
	tx_packet[1] = swap_u32(tx_packet[1]);
	tx_packet[2] = swap_u32(tx_packet[2]);
	rx_packet[0] = 0u;
	rx_packet[1] = 0u;
	rx_packet[2] = 0u;

	IOWR_32DIRECT(CORDIC_IP_0_BASE, CORDIC_CTRL_OFFSET, ctrl_value);

	alt_avalon_sgdma_construct_stream_to_mem_desc(
		&rx_desc,
		&rx_desc_next,
		(alt_u32 *)rx_packet,
		PACKET_BYTES,
		0);

	alt_avalon_sgdma_construct_mem_to_stream_desc(
		&tx_desc,
		&tx_desc_next,
		tx_packet,
		PACKET_BYTES,
		0,
		1,
		1,
		0);

	status = alt_avalon_sgdma_do_async_transfer(rx_dev, &rx_desc);
	if (status != 0) {
		alt_printf("RX DMA start error %d\n", status);
		return status;
	}

	status = alt_avalon_sgdma_do_async_transfer(tx_dev, &tx_desc);
	if (status != 0) {
		alt_printf("TX DMA start error %d\n", status);
		return status;
	}

	return 0;
}

static void capture_dma_output(void)
{
	rx_packet_words[0] = swap_u32(rx_packet[0]);
	rx_packet_words[1] = swap_u32(rx_packet[1]);
	rx_packet_words[2] = swap_u32(rx_packet[2]);
}

int main(void)
{
	alt_sgdma_dev *tx_dev;
	alt_sgdma_dev *rx_dev;
	unsigned int case_index = 0;
	alt_u32 sw_value;
	alt_u32 current_mode;
	alt_u32 selected_mode = CORDIC_MODE_ROTATION;
	app_state_t app_state = APP_WAIT_START;

	alt_putstr("CORDIC SW-controlled stream demo start\n");
	generate_random_cases();
	write_leds(0u);
	start_button_irq_init();

	tx_dev = alt_avalon_sgdma_open(SGDMA_0_NAME);
	rx_dev = alt_avalon_sgdma_open(SGDMA_1_NAME);
	if ((tx_dev == 0) || (rx_dev == 0)) {
		alt_putstr("SGDMA open failed\n");
		return -1;
	}

	alt_avalon_sgdma_register_callback(
		tx_dev,
		tx_dma_callback,
		ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK |
		ALTERA_AVALON_SGDMA_CONTROL_IE_DESC_COMPLETED_MSK,
		NULL);
	alt_avalon_sgdma_register_callback(
		rx_dev,
		rx_dma_callback,
		ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK |
		ALTERA_AVALON_SGDMA_CONTROL_IE_DESC_COMPLETED_MSK,
		NULL);

	LCD_Init();
	lcd_show_waiting();

	while (1) {
		sw_value = read_switches();
		current_mode = (sw_value & SW_MODE_MASK) ? CORDIC_MODE_VECTORING : CORDIC_MODE_ROTATION;

		switch (app_state) {
		case APP_WAIT_START:
			if (start_flag != 0u) {
				start_flag = 0u;
				selected_mode = current_mode;
				tx_done_flag = 0u;
				rx_done_flag = 0u;
				write_leds(LED_BUSY_MASK);
				LCD_SetCursor(0, 0);
				LCD_String("CORDIC RUNNING  ");
				usleep(800000);
				LCD_SetCursor(1, 0);
				LCD_String((selected_mode == CORDIC_MODE_VECTORING) ? "MODE VECTORING  " : "MODE ROTATION   ");
				usleep(800000);
				case_index = 0;
				app_state = APP_RUNNING;
			}
			break;

		case APP_RUNNING:
			if (case_index < NUM_SAMPLES) {
				if (start_case_dma(tx_dev, rx_dev, &stream_cases[case_index], selected_mode) != 0) {
					app_state = APP_ERROR;
					break;
				}
				app_state = APP_WAIT_DMA;
			}
			break;

		case APP_WAIT_DMA:
			if ((tx_done_flag != 0u) && (rx_done_flag != 0u)) {
				capture_dma_output();
				lcd_show_case_outputs(case_index);
				usleep(500000);
				case_index++;
				tx_done_flag = 0u;
				rx_done_flag = 0u;
				if (case_index == NUM_SAMPLES) {
					app_state = APP_DONE;
				}
				else {
					app_state = APP_RUNNING;
				}
			}
			break;

		case APP_DONE:
			write_leds(LED_DONE_MASK);
			lcd_show_done();
			lcd_show_waiting();
			app_state = APP_WAIT_START;
			break;

		case APP_ERROR:
			write_leds(LED_ERROR_MASK);
			lcd_show_error();
			lcd_show_waiting();
			app_state = APP_WAIT_START;
			break;

		default:
			app_state = APP_WAIT_START;
			break;
		}
	}

	return 0;
}
