# Host packages that mise cannot provide (mise.toml owns every other tool). `brew bundle
# install` installs them; `mise install` then provides the rest.

# Taps
tap "hudochenkov/sshpass" # For Tessera Frost

# Swift toolchains on Linux and Windows guests are installed with swiftly from the
# guest; on macOS the baseline is Xcode 26.6 (docs/architecture/toolchain-lanes.md).
brew "swiftly"

# Virtual machines
brew "lima" # Linux virtual machines
brew "qemu" # For Tessera Frost
brew "sshpass" # For Tessera Frost
brew "swtpm" # For Tessera Frost
cask "utm" # Windows virtual machines
