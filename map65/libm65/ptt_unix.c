/*
 * WSJT is Copyright (c) 2001-2006 by Joseph H. Taylor, Jr., K1JT, 
 * and is licensed under the GNU General Public License (GPL).
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <string.h>

static char ptt_override[256] = {0};
static char opened_path[256] = {0};
static int fd = -1;
static enum { PTT_IDLE, PTT_KEYED, PTT_UNCERTAIN } ptt_state = PTT_IDLE;

void ptt_set_override(const char *path)
{
    strncpy(ptt_override, path ? path : "", sizeof(ptt_override) - 1);
    ptt_override[sizeof(ptt_override) - 1] = '\0';
}

int ptt_serial(int port_fd, int *ntx, int *iptt)
{
    int status = 0;
    if (ioctl(port_fd, TIOCMGET, &status) < 0)
        return 1;

    if (*ntx)
        status |= TIOCM_RTS | TIOCM_DTR;
    else
        status &= ~(TIOCM_RTS | TIOCM_DTR);

    if (ioctl(port_fd, TIOCMSET, &status) < 0)
        return 1;

    *iptt = *ntx;
    return 0;
}

static void close_port(void)
{
    if (fd >= 0)
        close(fd);
    fd = -1;
    opened_path[0] = '\0';
    ptt_state = PTT_IDLE;
}

/* Return nonzero on failure, leaving the caller's confirmed PTT state intact. */
int ptt_(int *nport, int *ntx, int *iptt)
{
    (void)nport;

    /* Always release the open port, even when the next selection is disabled. */
    if (!*ntx) {
        if (fd >= 0 && ptt_serial(fd, ntx, iptt)) {
            ptt_state = PTT_UNCERTAIN;
            return 1;
        }
        ptt_state = PTT_IDLE;
        *iptt = 0;
        if (fd >= 0 && strcmp(opened_path, ptt_override))
            close_port();
        return 0;
    }

    /* A failed operation must be followed by a confirmed release before TX. */
    if (ptt_state == PTT_UNCERTAIN)
        return 1;
    if (ptt_state == PTT_KEYED) {
        *iptt = 1;
        return 0;
    }

    if (fd >= 0 && strcmp(opened_path, ptt_override))
        close_port();
    if (!*ptt_override) {
        *iptt = *ntx;
        return 0;
    }

    if (fd < 0) {
        fd = open(ptt_override, O_RDWR | O_NONBLOCK);
        if (fd < 0)
            return 1;
        strcpy(opened_path, ptt_override);
        int off = 0;
        int status = 0;
        if (ptt_serial(fd, &off, &status)) {
            ptt_state = PTT_UNCERTAIN;
            return 1;
        }
    }

    if (ptt_serial(fd, ntx, iptt)) {
        ptt_state = PTT_UNCERTAIN;
        return 1;
    }
    ptt_state = PTT_KEYED;
    return 0;
}

void ptt_close(void)
{
    if (fd >= 0) {
        int off = 0;
        int status = 0;
        ptt_serial(fd, &off, &status);
        close_port();
    }
}
