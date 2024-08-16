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

    # get os version
    my ($version, $sp, $host_distri) = get_os_release;
    my $sp_version = "$version.$sp";
    # install necessary packages
    zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Factory:/Head/standard/ yq");
    zypper_call "in yq";

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


    # velociraptor client install
    zypper_call "in velociraptor-client";
    systemctl "enable velociraptor-client";
    systemctl "is-enabled velociraptor-client";

    # generate config files
    assert_script_run "velociraptor-client config generate > server.conf";
    script_output 'yq -i ".defaults.event_max_wait = 1" server.conf';
    script_output 'yq -i ".defaults.event_max_wait_jitter = 1" server.conf';
    script_output 'yq -i ".defaults.event_change_notify_all_clients = true" server.conf';
    background_script_run "velociraptor-client frontend -v --config server.conf > /dev/null 2>&1 &";
    assert_script_run "velociraptor-client config client --config server.conf > client.conf";

    # update config file
    script_output 'yq -i ".Client.max_poll = 1" client.conf';
    script_output 'yq -i ".Client.max_poll_std = 1" client.conf';
    script_output 'yq -i ".Client.min_poll = 1" client.conf';
    script_output 'yq -i ".Client.default_max_wait = 1" client.conf';

    # copy config files
    assert_script_run "cp client.conf  /etc/velociraptor/client.config";

    # start client
    sleep 10;
    systemctl "restart velociraptor-client";
    systemctl "status velociraptor-client";
    # check server accessible
    assert_script_run "curl -k https://localhost:8000/server.pem";

    # generate server api config
    assert_script_run "velociraptor-client --config server.conf config api_client --name admin --role administrator api.config.yaml";
    # get client info from server
    assert_script_run "velociraptor-client --api_config ~/api.config.yaml query 'SELECT * FROM info()'";

    # get client id
    my $clientid = script_output('velociraptor-client --api_config ~/api.config.yaml query \'SELECT *, os_info.hostname as Hostname, client_id FROM clients()\' | grep -oP \'"client_id": "\K.*(?=")\'', 120);

    # add client monitoring
    my @artifacts = qw(SUSE.Linux.Audit.SystemLogins SUSE.Linux.Events.DNS SUSE.Linux.Events.ExecutableFiles SUSE.Linux.Events.ImmutableFile SUSE.Linux.Events.NewFiles SUSE.Linux.Events.NewFilesNoOwner SUSE.Linux.Events.NewHiddenFile SUSE.Linux.Events.NewZeroSizeLogFile SUSE.Linux.Events.Packages SUSE.Linux.Events.ProcessStatuses SUSE.Linux.Events.SSHLogin SUSE.Linux.Events.Services SUSE.Linux.Events.SshAuthorizedKeys SUSE.Linux.Events.SystemLogins SUSE.Linux.Events.TCPConnections SUSE.Linux.Events.Timers SUSE.Linux.Events.UserAccount SUSE.Linux.Events.UserGroupMembershipUpdates);
    foreach my $artifact (@artifacts) {
        assert_script_run("velociraptor-client --api_config ~/api.config.yaml query 'SELECT add_client_monitoring(artifact=\"$artifact\") FROM scope()'");
    }

    # generetae client events
    sleep 10;
    my $i = 0;
    while ($i < 10) {
        assert_script_run "echo 'Client Event exec' >> /home/genfile$i.sh";
        assert_script_run "chmod +x /home/genfile$i.sh";
        assert_script_run "echo 'Client Event exec' >> /tmp/genfile$i.sh";
        assert_script_run "chmod +x /tmp/genfile$i.sh";
        $i++;
    }
    sleep 60;
    # check for collected event on server
    script_output "ls -la /var/tmp/velociraptor/clients/$clientid/monitoring_logs/";
    script_output "ls -la /var/tmp/velociraptor/clients/$clientid/monitoring/";
    my $files = script_output "find /var/tmp/velociraptor/clients/$clientid/monitoring/ -type f -name '*.json' | awk -F/ '{print \$F}'";
    my @names = split /\s+/, $files;
    for (@names) {
        my @name = split /\//, $_;
        upload_logs($_, log_name => "artifact-$name[7].json");
    }
    # skipping validation on s390x due to https://jira.suse.com/browse/SENS-122
    if (!is_s390x) {
        script_output "grep -r -i genfile* /var/tmp/velociraptor/clients/$clientid/*";
    }
}
1;
