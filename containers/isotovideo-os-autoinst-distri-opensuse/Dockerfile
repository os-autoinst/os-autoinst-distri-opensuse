#!BuildTag: isotovideo:qemu-x86-os-autoinst-distri-opensuse

# hadolint ignore=DL3006
FROM opensuse/tumbleweed
# hadolint ignore=DL3034,DL3037
RUN zypper -n in os-autoinst-qemu-x86 os-autoinst-distri-opensuse-deps && zypper clean
ENTRYPOINT ["/usr/bin/isotovideo"]
