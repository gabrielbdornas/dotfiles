# Arch-based image approximating an Omarchy machine, for testing setup/'s
# config/hypr/ symlink behavior (link_dotfile()'s collision-safety path -
# see docs/adr/0006) against Omarchy's real default Hyprland config, not a
# placeholder. See docker/README.md for how to use this.
#
# This does NOT run Omarchy's actual installer
# (github.com/omacom/omarchy/install.sh) - that installs hundreds of
# packages plus a display manager and boot-splash tooling meant for real
# hardware, none of which is practical or meaningful inside a container.
# Instead it reproduces the file layout a real Omarchy install leaves under
# ~/.config/hypr by extracting Omarchy's own default/hypr directory
# straight from their repo tarball (curl + tar only, deliberately not
# `git clone`, so git still isn't preinstalled here either - same
# install-if-missing reasoning as arch-test.Dockerfile).
#
# Worth knowing: Omarchy's actual hypr config is Lua-based (bindings.lua,
# input.lua, ...), not plain .conf files - it doesn't collide with
# config/hypr/keybindings.conf or monitors.conf on exact filenames, only on
# both living in the same ~/.config/hypr/ directory.

FROM archlinux:latest

RUN pacman -Sy --noconfirm --needed sudo curl ca-certificates && \
    pacman -Scc --noconfirm

RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester && \
    chmod 0440 /etc/sudoers.d/tester

RUN mkdir -p /home/tester/.config/hypr && \
    curl -fsSL https://github.com/omacom/omarchy/archive/refs/heads/quattro.tar.gz \
      | tar -xz -C /home/tester/.config/hypr --strip-components=3 omarchy-quattro/default/hypr && \
    chown -R tester:tester /home/tester/.config

USER tester
WORKDIR /home/tester

CMD ["bash"]
