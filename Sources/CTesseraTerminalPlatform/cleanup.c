#include "CTesseraTerminalPlatform.h"

#ifdef _WIN32

void tessera_cleanup_clear(void) {}
void tessera_cleanup_perform(void) {}
void tessera_cleanup_install_handlers(void) {}
int tessera_cleanup_has_saved_termios_for_testing(void) { return 0; }

#else

#include <signal.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct tessera_cleanup_state {
  int input_fd;
  int output_fd;
  unsigned char *teardown_bytes;
  size_t teardown_count;
  struct termios saved_termios;
  int has_saved_termios;
};

static _Atomic(struct tessera_cleanup_state *) current_state = NULL;
static atomic_flag handlers_installed = ATOMIC_FLAG_INIT;

static void write_all_best_effort(int fd, const unsigned char *bytes, size_t count) {
  size_t offset = 0;

  while (offset < count) {
    ssize_t written = write(fd, bytes + offset, count - offset);
    if (written <= 0) {
      return;
    }
    offset += (size_t)written;
  }
}

void tessera_cleanup_install(
  int input_fd,
  int output_fd,
  const unsigned char *teardown_bytes,
  size_t teardown_count,
  const struct termios *saved_termios
) {
  struct tessera_cleanup_state *state = malloc(sizeof(struct tessera_cleanup_state));
  if (state == NULL) {
    return;
  }

  state->input_fd = input_fd;
  state->output_fd = output_fd;
  state->teardown_count = teardown_count;
  state->has_saved_termios = saved_termios != NULL;

  if (saved_termios != NULL) {
    state->saved_termios = *saved_termios;
  }

  if (teardown_count > 0) {
    state->teardown_bytes = malloc(teardown_count);
    if (state->teardown_bytes == NULL) {
      free(state);
      return;
    }
    memcpy(state->teardown_bytes, teardown_bytes, teardown_count);
  } else {
    state->teardown_bytes = NULL;
  }

  struct tessera_cleanup_state *previous = atomic_exchange(&current_state, state);
  if (previous != NULL) {
    free(previous->teardown_bytes);
    free(previous);
  }
}

void tessera_cleanup_clear(void) {
  struct tessera_cleanup_state *state = atomic_exchange(&current_state, NULL);
  if (state != NULL) {
    free(state->teardown_bytes);
    free(state);
  }
}

void tessera_cleanup_perform(void) {
  struct tessera_cleanup_state *state = atomic_load(&current_state);
  if (state == NULL) {
    return;
  }

  if (state->teardown_bytes != NULL && state->teardown_count > 0) {
    write_all_best_effort(state->output_fd, state->teardown_bytes, state->teardown_count);
  }

  if (state->has_saved_termios) {
    tcsetattr(state->input_fd, TCSADRAIN, &state->saved_termios);
  }
}

void tessera_cleanup_perform_and_reraise(int signal_number) {
  tessera_cleanup_perform();
  signal(signal_number, SIG_DFL);
  raise(signal_number);
}

int tessera_cleanup_has_saved_termios_for_testing(void) {
  struct tessera_cleanup_state *state = atomic_load(&current_state);
  if (state == NULL) {
    return 0;
  }
  return state->has_saved_termios;
}

static void tessera_cleanup_signal_handler(int signal_number) {
  tessera_cleanup_perform_and_reraise(signal_number);
}

void tessera_cleanup_install_handlers(void) {
  if (atomic_flag_test_and_set(&handlers_installed)) {
    return;
  }

  signal(SIGINT, tessera_cleanup_signal_handler);
  signal(SIGTERM, tessera_cleanup_signal_handler);
  signal(SIGHUP, tessera_cleanup_signal_handler);
  signal(SIGQUIT, tessera_cleanup_signal_handler);
  atexit(tessera_cleanup_perform);
}

#endif
