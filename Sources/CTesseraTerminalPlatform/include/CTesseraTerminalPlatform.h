#ifndef C_TESSERA_TERMINAL_PLATFORM_H
#define C_TESSERA_TERMINAL_PLATFORM_H

#include <stddef.h>

#ifndef _WIN32
#include <termios.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WIN32
void tessera_cleanup_install(
  int input_fd,
  int output_fd,
  const unsigned char *teardown_bytes,
  size_t teardown_count,
  const struct termios *saved_termios
);
#else
void tessera_cleanup_install_windows(
  void *input_handle,
  void *output_handle,
  const unsigned char *teardown_bytes,
  size_t teardown_count,
  unsigned int saved_input_mode,
  unsigned int saved_output_mode
);
#endif

void tessera_cleanup_clear(void);
void tessera_cleanup_perform(void);
void tessera_cleanup_install_handlers(void);
#ifndef _WIN32
void tessera_cleanup_perform_and_reraise(int signal_number);
#endif
int tessera_cleanup_has_saved_termios_for_testing(void);
int tessera_cleanup_has_saved_windows_modes_for_testing(void);
int tessera_cleanup_has_installed_handlers_for_testing(void);

#ifdef __cplusplus
}
#endif

#endif
