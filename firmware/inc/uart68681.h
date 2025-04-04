#ifndef UART68681_H
#define UART68681_H

#include <stdint.h>

typedef struct {

        // 0000
        union {
                volatile uint8_t mr1a;   // Mode Register A
                volatile uint8_t mr2a;   // Mode Register A
        };

        // 0001
        union {
                volatile uint8_t sra;    // Status Register A
                volatile uint8_t csra;   // Clock-Select Register A (TX)
        };

        // 0010
        volatile uint8_t cra;            // Command Register A

        // 0011
        union {
                volatile uint8_t rba;    // Receiver Buffer A
                volatile uint8_t tba;    // Transmitter Buffer A
        };

        // 0100
        union {
                volatile uint8_t ipcr;   // Input Port Change Register
                volatile uint8_t acr;    // Auxiliary Control Register
        };

        // 0101
        union {
                volatile uint8_t isr;    // Interrupt Status Register
                volatile uint8_t imr;    // Interrupt Mask Register
        };

        // 0110
        union {
                volatile uint8_t cur;    // Counter Mode: Current MSB of Counter
                volatile uint8_t ctur;   // Counter/Timer Upper Register
        };

        // 0111
        union {
                volatile uint8_t clr;    // Counter Mode: Current LSB of Counter
                volatile uint8_t ctlr;   // Counter/Timer Lower Register
        };

        // 1000
        union {
                volatile uint8_t mr1b;   // Mode Register B
                volatile uint8_t mr2b;   // Mode Register B
        };

        // 1001
        union {
                volatile uint8_t srb;    // Status Register A
                volatile uint8_t csrb; // Clock-Select Register A (RX)
        };

        // 1010
        volatile uint8_t crb;            // Command Register A

        // 1011
        union {
                volatile uint8_t rbb;    // Receiver Buffer A
                volatile uint8_t tbb;    // Transmitter Buffer A
        };

        // 1100
        volatile uint8_t ivr;            // Interrupt-Vector Register

        // 1101
        union {
                volatile uint8_t ip;     // Input Port
                volatile uint8_t opcr;   // Output Port Configuration Register
        };

        // 1110
        union {
                volatile uint8_t cnt_start; // Start-Counter Command
                volatile uint8_t opr_set;   // Output Port Register Bit Set Command
        };

        // 1111
        union {
                volatile uint8_t cnt_stop;  // Stop-Counter Command
                volatile uint8_t opr_reset; // Output Port Register Bit Reset Command
        };

} UART68681_t;

#define UART_BASE ((uint32_t)0x20000000)
#define uart ((UART68681_t *)UART_BASE)

#endif
