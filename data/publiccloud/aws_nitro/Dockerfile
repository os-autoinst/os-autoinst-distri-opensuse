FROM registry.suse.com/suse/sle15
RUN echo -e 'echo Hello Enclave\nsleep 300' > /entrypoint.sh
ENTRYPOINT ["bash", "/entrypoint.sh"]
