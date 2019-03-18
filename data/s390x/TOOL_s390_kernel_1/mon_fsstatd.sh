# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/usr/bin/env bash
#
#  07.03.2018 Adapted to SLES15:
#                       There is no more a "combined" mon_statd service.
#                       Instead, separate mon_procd and mon_fsstatd
#                       services exist.


for f in lib/*.sh; do source $f; done

sed -i 's/FSSTAT="no"/FSSTAT="yes"/' /etc/sysconfig/mon_statd
sed -i 's/PROC="no"/PROC="yes"/' /etc/sysconfig/mon_statd

# Get config
s390_config_check S390_mon_statd

init_tests
start_section 0 "Testing Mon Tool"
    start_section 1 "Basic User option Verification"
        if isVM; then
            assert_exec 0 modprobe monwriter max_bufs=8192

            sleep 2

            if ( isSles15 ); then
                service mon_fsstatd status
                service mon_procd status

                sleep 2
                assert_exec 0 "service mon_fsstatd stop"
                assert_exec 0 "service mon_procd stop"

                sleep 2
                assert_exec 0 "service mon_fsstatd start"
                assert_exec 0 "service mon_procd start"
            else
                service mon_statd status

                sleep 2
                assert_exec 0 "service mon_statd stop"

                sleep 2
                assert_exec 0 "service mon_statd start"
            fi

            sleep 2
            assert_exec 0 "pidof mon_fsstatd"
            assert_exec 0 "pidof mon_procd"

            sleep 2

            if ( isSles15 ); then
                assert_exec 0 "service mon_fsstatd restart"
                assert_exec 0 "service mon_procd restart"
            else
                assert_exec 0 "service mon_statd restart"
            fi

            sleep 2
            assert_exec 0 "mon_fsstatd -h"

            sleep 2
            assert_exec 0 "mon_fsstatd --help"

            sleep 2
            assert_exec 0 "mon_fsstatd -v"

            sleep 2
            assert_exec 0 "mon_fsstatd --version"

            sleep 2
            assert_exec 0 "mon_fsstatd -i 30"

            sleep 2
            assert_exec 0 "mon_procd -h"

            sleep 2
            assert_exec 0 "mon_procd --help"

            sleep 2
            assert_exec 0 "mon_procd -v"

            sleep 2
            assert_exec 0 "mon_procd --version"

            sleep 2
            assert_exec 0 "mon_procd -i 30"

            sleep 2
            assert_exec 0 "mon_procd -a &"

            sleep 2
            assert_exec 0 "killall mon_procd"

            sleep 2
            assert_exec 0 "mon_fsstatd -a &"

            sleep 2
            assert_exec 0 "killall mon_fsstatd"

            sleep 2
            assert_exec 0 "mon_procd -v"
        else
            assert_exec 1 "modprobe vmcp"
            echo "Not applicable in LPAR"
        fi
    end_section 1
    show_test_results
end_section 0
