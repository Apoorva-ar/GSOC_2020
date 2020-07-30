
/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "ps7_init.h"
#include "xparameters.h"
#include "xil_io.h"

int main()
{
	int i;
    init_platform();
    ps7_post_config();
    xil_printf("Hello World\n\r");
    xil_printf("Successfully ran Hello World application");

    for(i = 0; i<10;i++)
	{
    	Xil_Out32(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR + 4*i, i + 0xaabbccdd);
    }

    for(i = 0; i<10;i++)
	{
    	xil_printf("values at address %x is %x",XPAR_AXI_BRAM_CTRL_1_S_AXI_BASEADDR +4*i, Xil_In32(XPAR_AXI_BRAM_CTRL_1_S_AXI_BASEADDR +4*i) );
    }

    cleanup_platform();
    return 0;

}
