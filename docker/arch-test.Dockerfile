# Minimal Arch Linux image for testing the pacman branch of setup/ end to
# end - mirrors docker/ubuntu-test.Dockerfile's principle: only
# sudo/curl/ca-certificates preinstalled (the bare minimum to run the curl
# one-liner at all), everything else (git, gh, jq, infisical, openssh,
# zsh, ...) installed by setup.sh/bootstrap.sh themselves, so the test
# actually exercises those install-if-missing code paths instead of
# silently skipping them. See docker/README.md for how to use this.

FROM archlinux:latest

RUN pacman -Sy --noconfirm --needed sudo curl ca-certificates && \
    pacman -Scc --noconfirm

# A regular sudo-capable user, not root - setup/ assumes it's run as the
# machine's normal user with sudo access, same as a real desktop install.
RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester && \
    chmod 0440 /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester

CMD ["bash"]
