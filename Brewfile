# Host packages that mise cannot provide (mise.toml owns every other tool). `brew bundle
# install` installs them; `mise install` then provides the rest.

# Swift toolchains on Linux and Windows guests are installed with swiftly from the
# guest; on macOS the baseline is Xcode 26.6 (docs/architecture/toolchain-lanes.md).
brew "swiftly"

# Virtual machines
brew "lima" # Linux virtual machines
cask "utm" # Windows virtual machines (scripts/vm.py windows-*)
