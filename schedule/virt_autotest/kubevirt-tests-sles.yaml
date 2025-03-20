name:           kubevirt-tests
description:    >
    Maintainer: Nan Zhang <nan.zhang@suse.com> qe-virt@suse.de
    Kubevirt server & agent node installation and test modules
vars:
    MAX_JOB_TIME: 72000
schedule:
    - '{{barrier_setup}}'
    - '{{bootup_and_install}}'
    - '{{kubevirt_tests}}'
conditional_schedule:
    pxe_boot:
        IPXE:
            0:
                - boot/boot_from_pxe
            1:
                - installation/ipxe_install
    barrier_setup:
        SERVICE:
            rke2-server:
                - virt_autotest/kubevirt_barriers
    bootup_and_install:
        RUN_TEST_ONLY:
            0:
                - autoyast/prepare_profile
                - '{{pxe_boot}}'
                - autoyast/installation
                - virt_autotest/login_console
    kubevirt_tests:
        SERVICE:
            rke2-server:
                - virt_autotest/kubevirt_tests_server
            rke2-agent:
                - virt_autotest/kubevirt_tests_agent
