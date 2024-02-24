#/bin/bash

transactional-update shell
zypper ar http://download.suse.de/ibs/QA:/Head/openSUSE_Tumbleweed/ qa-head
zypper ref
zypper in screen
zypper in python3 bzip2
tar -xf sleperf.tar
sleperf/SLEPerf/common-infra/installer.sh
sleperf/SLEPerf/scheduler-service/installer.sh
mkdir -p /abuild
mkdir -p /var/log/qa
exit
reboot