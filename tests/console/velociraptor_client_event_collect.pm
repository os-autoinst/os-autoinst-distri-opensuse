# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: velociraptor-client
# Summary: install velociraptor-client and collect events on server
# Maintainer: Gayane Osipyan <gosipyan@suse.com>

use base "consoletest";
use testapi;
use strict;
use warnings;
use version_utils;
use utils;
use Utils::Architectures;
use repo_tools "generate_version";
use serial_terminal "select_serial_terminal";
use python_version_utils;

sub run {

    select_serial_terminal;

    # get python version
    my $system_python_version = get_system_python_version();

    # get os version
    my ($version, $sp, $host_distri) = get_os_release;
    my $sp_version = "$version.$sp";

    # setup repositories
    zypper_call "ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-15:/Update/standard/ sle15update";
    zypper_call "ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-15-SP4:/Update/standard/ sle15SP4update";
    zypper_call "ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update/standard/ sle15SP1update";
    if (is_sle) {
        if (is_sle('=15-SP6') || $sp_version == '15.6') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP6/ sensor");
        }
        elsif (is_sle('=15-SP5') || $sp_version == '15.5') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP5/ sensor");
        }
        elsif (is_sle('=15-SP4') || $sp_version == '15.4') {
            zypper_call("ar -f --no-gpgcheck  http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP4/ sensor");
        }
        else {
            record_info("No repo", "Missing source repository");
            die("Missing sensor repository");
        }
    }

    # create config dir to run server container
    assert_script_run "cd /root";
    assert_script_run "mkdir -p vrr/config vrr/data vrr/logs vrr/definitions";

    # install podman and required dependencies
    zypper_call "in cni podman";

    # run server as container
    assert_script_run "podman run -d --rm     --name vrr     -v /root/vrr/data:/data:Z     -v /root/vrr/config:/config:Z     -v /root/vrr/logs:/logs:Z     -v /root/vrr/definitions:/definitions:Z     -p 8001:8001     -p 8889:8889     -p 8000:8000     -p 8003:8003     registry.opensuse.org/security/sensor/containers/linux-security-sensor";

    # verify container running
    validate_script_output("podman ps", qr/vrr/);
    validate_script_output("podman container inspect --format='{{.State.Running}}' vrr", qr/true/);

    # velociraptor client install
    zypper_call "in velociraptor-client";

    systemctl "enable velociraptor-client";
    systemctl "is-enabled velociraptor-client";

    # copy config files
    assert_script_run "cp /root/vrr/config/client.conf  /etc/velociraptor/client.config";
    assert_script_run "sed -i \"s/sensor-frontend/localhost/g\" /etc/velociraptor/client.config";

    # start client
    systemctl "start velociraptor-client";
    systemctl "status velociraptor-client";

    # check server accessible
    assert_script_run "curl --insecure --user admin:admin https://localhost:8889/app/index.html";

    # generate server api config
    assert_script_run "sed -i 's/sensor-frontend/localhost/g' vrr/config/server.conf";
    assert_script_run "velociraptor-client --config vrr/config/server.conf config api_client --name admin --role administrator api.config.yaml";
    # get client info from server
    assert_script_run "velociraptor-client --api_config ~/api.config.yaml query 'SELECT * FROM info()'";

    # get client id
    my $clientid = script_output('velociraptor-client --api_config ~/api.config.yaml query \'SELECT *, os_info.hostname as Hostname, client_id FROM clients()\' | grep -oP \'"client_id": "\K.*(?=")\'', 120);

    # install virtualenv
    assert_script_run "$system_python_version  -m venv vrr-api";
    assert_script_run "vrr-api/bin/pip install pyvelociraptor";
    # add client monitoring
    assert_script_run('vrr-api/bin/pyvelociraptor --config api.config.yaml \'SELECT add_client_monitoring(artifact="SUSE.Linux.Events.ExecutableFiles") FROM scope()\'');
    sleep 90;
    # generetae client events
    my $i = 0;
    while ($i < 10) {
        assert_script_run "echo 'Client Event exec' >> /home/genfile$i.sh";
        assert_script_run "chmod +x /home/genfile$i.sh";
        assert_script_run "echo 'Client Event exec' >> /tmp/genfile$i.sh";
        assert_script_run "chmod +x /tmp/genfile$i.sh";
        $i++;
    }

    # wait for event collection
    sleep 180;
    # check for collected event on server
    script_output "ls /root/vrr/data/clients/$clientid/";
    script_output "ls /root/vrr/data/clients/$clientid/monitoring_logs/";
    script_output "ls /root/vrr/data/clients/$clientid/monitoring/";
    assert_script_run "grep -r -i genfile* /root/vrr/data/clients/$clientid/*";

}

1;
