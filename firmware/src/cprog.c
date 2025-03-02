#include "uart.h"
#include <stdint.h>
#include <string.h>

extern int printf_(const char* format, ...);
extern int _getchar(void);

/******************************************************************************
 * Simple Monitor Program for 68k
 * 
 * Uses: 
 *   extern int printf_(const char *fmt, ...);
 *   extern int _getchar(void);
 *
 * Commands:
 *   m.b <addr>            Read a byte from <addr>
 *   m.w <addr>            Read a word (16 bits) from <addr>
 *   m.l <addr>            Read a long (32 bits) from <addr>
 *
 *   mw.b <addr> <val>     Write <val> (byte) to <addr>
 *   mw.w <addr> <val>     Write <val> (word) to <addr>
 *   mw.l <addr> <val>     Write <val> (long) to <addr>
 *
 *   md.b <addr> <count>   Dump <count> bytes from <addr>, 16 per line w/ ASCII
 *   md.w <addr> <count>   Dump <count> words (16 bits each) from <addr>, 8 per line
 *   md.l <addr> <count>   Dump <count> longs (32 bits each) from <addr>, 4 per line
 *
 * Enter "help" for a short summary.
 ******************************************************************************/

int strcmp(const char *s1, const char *s2) {
	while (*s1 == *s2) {
		if (*s1 == '\0') {
			return 0;
		}
		s1++;
		s2++;
	}

	return (unsigned char)*s1 - (unsigned char)*s2;
}

/* You might adjust these for your environment */
#define MAX_LINE_LEN  80

/*---------------------------------------------------------------------------
 *  Helper: read a line of text from the console, up to MAX_LINE_LEN
 *  Blocking: waits for user to type a line and press Enter.
 *  Returns length of the line stored in 'buf'. (buf is always null-terminated)
 *---------------------------------------------------------------------------*/
static int get_line(char *buf, int buf_size)
{
    char c;
    int i;

    i = 0;

    if (buf_size <= 0) {
        return 0;
    }

    while (1) {
        c = (char)_getchar();   /* read a character (blocking) */
        if (c == '\r' || c == '\n') {
            /* Echo if desired; here we’ll echo a newline. */
            printf_("\n");
            break;
        } else if (c == 0x08 || c == 0x7F) {
            /* Handle backspace if you want. For simplicity, skip or implement as needed. */
            if (i > 0) i--;
        } else {
            /* Store character if we have space */
            if (i < buf_size - 1) {
                buf[i++] = c;
            }
            /* Echo the character back (optional) */
            //printf_("%c", c);
        }
    }

    buf[i] = '\0';  /* null-terminate */
    return i;
}

/*---------------------------------------------------------------------------
 *  Helper: parseHex
 *  Converts a string in hex format (e.g. "1A3F") to an unsigned long.
 *  Returns 1 on success, 0 on failure.
 *---------------------------------------------------------------------------*/
static int parseHex(const char *s, unsigned long *val)
{
    unsigned long result = 0;
    if (!s || !*s) return 0;

    while (*s) {
        char c = *s++;
        unsigned digit = 0;
        if (c >= '0' && c <= '9') {
            digit = (unsigned)(c - '0');
        } else if (c >= 'A' && c <= 'F') {
            digit = (unsigned)(c - 'A') + 10U;
        } else if (c >= 'a' && c <= 'f') {
            digit = (unsigned)(c - 'a') + 10U;
        } else {
            return 0; /* invalid hex digit */
        }
        result = (result << 4) | digit;
    }
    *val = result;
    return 1;
}

/*---------------------------------------------------------------------------
 *  Dump bytes: prints hex and ASCII side by side
 *  Starting address is 'addr', number of bytes is 'count'
 *  Prints 16 bytes per line.
 *---------------------------------------------------------------------------*/
static void dump_bytes(unsigned long addr, unsigned long count)
{
    unsigned long start = addr;
    unsigned char *p = (unsigned char *)addr;
    const unsigned long per_line = 16;

    while (count > 0) {
        unsigned long line_count = (count > per_line) ? per_line : count;
        printf_("%08lX: ", addr);

        /* Print hex bytes */
        for (unsigned long i = 0; i < line_count; i++) {
            printf_("%02X ", p[i]);
        }

        /* If fewer than 16, pad alignment spaces in the hex area */
        if (line_count < per_line) {
            for (unsigned long i = line_count; i < per_line; i++) {
                printf_("   ");
            }
        }

        /* Print ASCII representation */
        printf_(" |");
        for (unsigned long i = 0; i < line_count; i++) {
            unsigned char c = p[i];
            if (c < 32 || c > 126) {
                c = '.';  /* non-printable -> dot */
            }
            printf_("%c", c);
        }
        printf_("|");

        /* Move to next line */
        printf_("\n");

        p += line_count;
        addr += line_count;
        count -= line_count;
    }
}

/*---------------------------------------------------------------------------
 *  Dump words (16 bits). 8 words per line.
 *  No ASCII is displayed here (you can adapt if you like).
 *---------------------------------------------------------------------------*/
static void dump_words(unsigned long addr, unsigned long count)
{
    unsigned short *p = (unsigned short *)addr;
    const unsigned long per_line = 8;
    unsigned long i, line_count;

    while (count > 0) {
        line_count = (count > per_line) ? per_line : count;
        printf_("%08lX: ", (unsigned long)p);

        for (i = 0; i < line_count; i++) {
            /* For real 68k, ensure alignment or handle bus errors carefully. */
            printf_("%04X ", p[i]);
        }
        printf_("\n");

        p += line_count;
        count -= line_count;
    }
}

/*---------------------------------------------------------------------------
 *  Dump longs (32 bits). 4 longs per line.
 *---------------------------------------------------------------------------*/
static void dump_longs(unsigned long addr, unsigned long count)
{
    unsigned long *p = (unsigned long *)addr;
    const unsigned long per_line = 4;
    unsigned long i, line_count;

    while (count > 0) {
        line_count = (count > per_line) ? per_line : count;
        printf_("%08lX: ", (unsigned long)p);

        for (i = 0; i < line_count; i++) {
            /* For real 68k, ensure alignment. */
            printf_("%08lX ", p[i]);
        }
        printf_("\n");

        p += line_count;
        count -= line_count;
    }
}

/*---------------------------------------------------------------------------
 *  Process one line of input: parse the command and arguments, perform action.
 *---------------------------------------------------------------------------*/
static void process_command(char *line)
{
    /* Tokenize the input. Very simple approach: split by spaces. */
    char *argv[4];
    int argc = 0;
    char *token = line;

    /* Break up to a few tokens */
    for (argc = 0; argc < 4; argc++) {
        while (*token == ' ') {
            token++;
        }
        if (*token == '\0') {
            argv[argc] = 0;
            break;
        }
        argv[argc] = token;
        /* find end of this token */
        while (*token && *token != ' ') {
            token++;
        }
        if (*token) {
            *token++ = '\0'; /* null-terminate token */
        }
    }

    /* If empty line, do nothing */
    if (argc == 0 || !argv[0]) {
        return;
    }

    /* "help" command */
    if (!strcmp(argv[0], "help")) {
        printf_("Commands:\n");
        printf_("  m.b <addr>            Read a byte\n");
        printf_("  m.w <addr>            Read a word\n");
        printf_("  m.l <addr>            Read a long\n");
        printf_("  mw.b <addr> <val>     Write a byte\n");
        printf_("  mw.w <addr> <val>     Write a word\n");
        printf_("  mw.l <addr> <val>     Write a long\n");
        printf_("  md.b <addr> <count>   Dump bytes\n");
        printf_("  md.w <addr> <count>   Dump words\n");
        printf_("  md.l <addr> <count>   Dump longs\n");
        return;
    }

    /* m.b / m.w / m.l <addr> ----------------------------------------------- */
    if (!strcmp(argv[0], "m.b") && argc >= 2) {
        unsigned long addr;
        if (parseHex(argv[1], &addr)) {
            unsigned char val = *(volatile unsigned char *)addr;
            printf_("Byte at 0x%08lX = 0x%02X\n", addr, val);
        } else {
            printf_("Parse error: invalid address.\n");
        }
        return;
    }

    if (!strcmp(argv[0], "m.w") && argc >= 2) {
        unsigned long addr;
        if (parseHex(argv[1], &addr)) {
            /* Beware alignment on real 68k */
            unsigned short val = *(volatile unsigned short *)addr;
            printf_("Word at 0x%08lX = 0x%04X\n", addr, val);
        } else {
            printf_("Parse error: invalid address.\n");
        }
        return;
    }

    if (!strcmp(argv[0], "m.l") && argc >= 2) {
        unsigned long addr;
        if (parseHex(argv[1], &addr)) {
            unsigned long val = *(volatile unsigned long *)addr;
            printf_("Long at 0x%08lX = 0x%08lX\n", addr, val);
        } else {
            printf_("Parse error: invalid address.\n");
        }
        return;
    }

    /* mw.b / mw.w / mw.l <addr> <val> -------------------------------------- */
    if (!strcmp(argv[0], "mw.b") && argc >= 3) {
        unsigned long addr, val;
        if (parseHex(argv[1], &addr) && parseHex(argv[2], &val)) {
            *(volatile unsigned char *)addr = (unsigned char)val;
            printf_("Wrote 0x%02X to [0x%08lX]\n", (unsigned char)val, addr);
        } else {
            printf_("Parse error: usage: mw.b <addr> <val>\n");
        }
        return;
    }

    if (!strcmp(argv[0], "mw.w") && argc >= 3) {
        unsigned long addr, val;
        if (parseHex(argv[1], &addr) && parseHex(argv[2], &val)) {
            /* Beware alignment on real 68k */
            *(volatile unsigned short *)addr = (unsigned short)val;
            printf_("Wrote 0x%04X to [0x%08lX]\n", (unsigned short)val, addr);
        } else {
            printf_("Parse error: usage: mw.w <addr> <val>\n");
        }
        return;
    }

    if (!strcmp(argv[0], "mw.l") && argc >= 3) {
        unsigned long addr, val;
        if (parseHex(argv[1], &addr) && parseHex(argv[2], &val)) {
            *(volatile unsigned long *)addr = val;
            printf_("Wrote 0x%08lX to [0x%08lX]\n", val, addr);
        } else {
            printf_("Parse error: usage: mw.l <addr> <val>\n");
        }
        return;
    }

    /* md.b / md.w / md.l <addr> <count> ------------------------------------ */
    if (!strcmp(argv[0], "md.b") && argc >= 3) {
        unsigned long addr, count;
        if (parseHex(argv[1], &addr) && parseHex(argv[2], &count)) {
            dump_bytes(addr, count);
        } else {
            printf_("Parse error: usage: md.b <addr> <count>\n");
        }
        return;
    }

    if (!strcmp(argv[0], "md.w") && argc >= 3) {
        unsigned long addr, count;
        if (parseHex(argv[1], &addr) && parseHex(argv[2], &count)) {
            dump_words(addr, count);
        } else {
            printf_("Parse error: usage: md.w <addr> <count>\n");
        }
        return;
    }

    if (!strcmp(argv[0], "md.l") && argc >= 3) {
        unsigned long addr, count;
        if (parseHex(argv[1], &addr) && parseHex(argv[2], &count)) {
            dump_longs(addr, count);
        } else {
            printf_("Parse error: usage: md.l <addr> <count>\n");
        }
        return;
    }

    /* If we get here, command not recognized */
    printf_("Unknown command: %s\n", argv[0]);
}

/*---------------------------------------------------------------------------
 *  Main Monitor Loop
 *---------------------------------------------------------------------------*/
void c_prog_entry(void) {

    char linebuf[MAX_LINE_LEN];

    printf_("Simple 68k Monitor. Type 'help' for commands.\n");

    while (1) {
        printf_("> ");
        get_line(linebuf, MAX_LINE_LEN);
        process_command(linebuf);
    }

    return;
}

