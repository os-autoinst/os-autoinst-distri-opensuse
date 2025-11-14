FROM registry.suse.com/suse/sle15:latest

ARG ADDITIONAL_MODULES

RUN --mount=type=secret,id=SUSEConnect,required \
    --mount=type=secret,id=SCCcredentials,required \
    zypper -n --gpg-auto-import-keys in gvim