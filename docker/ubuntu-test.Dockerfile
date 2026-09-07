# Minimal Ubuntu image for testing the apt branch of setup/ (setup.sh,
# bootstrap.sh, system.sh, user.sh) - day-to-day development happens on
# Arch, so this is the only way to exercise the apt-specific code paths
# before it runs on a real Debian/Ubuntu machine. See docker/README.md for
# how to use this.
#
# Only sudo/curl/ca-certificates are preinstalled here - the bare minimum to
# run the curl one-liner at all (equivalent to "the human already has a
# working terminal and network access"). git and everything else setup.sh
# installs itself are deliberately left out, so this test actually exercises
# those install-if-missing code paths instead of silently skipping them.

FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# A regular sudo-capable user, not root - setup/ assumes it's run as the
# machine's normal user with sudo access, same as a real desktop install.
RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester && \
    chmod 0440 /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester

CMD ["bash"]
