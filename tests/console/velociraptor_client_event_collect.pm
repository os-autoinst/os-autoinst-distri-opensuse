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

    # generate server api config
    assert_script_run "velociraptor-client --config server.conf config api_client --name admin --role administrator api.config.yaml";
    # get client info from server
    sleep 10;
    assert_script_run "velociraptor-client --api_config ~/api.config.yaml query 'SELECT * FROM info()'";

    # add client monitoring
    my @artifacts = qw(SUSE.Linux.Events.DNS SUSE.Linux.Events.ExecutableFiles SUSE.Linux.Events.ImmutableFile SUSE.Linux.Events.NewFiles SUSE.Linux.Events.NewFilesNoOwner SUSE.Linux.Events.NewHiddenFile SUSE.Linux.Events.NewZeroSizeLogFile SUSE.Linux.Events.Packages SUSE.Linux.Events.ProcessStatuses SUSE.Linux.Events.SSHLogin SUSE.Linux.Events.Services SUSE.Linux.Events.SshAuthorizedKeys SUSE.Linux.Events.SystemLogins SUSE.Linux.Events.TCPConnections SUSE.Linux.Events.Timers SUSE.Linux.Events.UserAccount SUSE.Linux.Events.UserGroupMembershipUpdates);
    foreach my $artifact (@artifacts) {
        if ($artifact == 'SUSE.Linux.Events.Packages' || $artifact == 'SUSE.Linux.Events.SshAuthorizedKeys') {
            script_run("velociraptor-client --api_config ~/api.config.yaml query 'SELECT add_client_monitoring(artifact=\"$artifact\", parameters=dict(period=\"10\")) FROM scope()' > /dev/null");

        }
        else {
            script_run("velociraptor-client --api_config ~/api.config.yaml query 'SELECT add_client_monitoring(artifact=\"$artifact\") FROM scope()' > /dev/null");
        }
    }

    # start client
    systemctl "restart velociraptor-client";
    systemctl "status velociraptor-client";
    sleep 10;

    # trigger SUSE.Linux.Events.DNS
    assert_script_run "dig localhost";
    assert_script_run "host localhost";
    assert_script_run "nslookup localhost";
    # trigger SUSE.Linux.Events.ExecutableFiles
    script_run "echo 'Client Event exec' >> /home/genfileh.sh";
    script_run "chmod +x /home/genfileh.sh";
    script_run "echo 'Client Event exec' >> /tmp/genfilet.sh";
    script_run "chmod +x /tmp/genfilet.sh";
    # trigger SUSE.Linux.Events.ImmutableFile
    script_run "echo 'Immutible file' >> /home/immutible.txt";
    script_run "chattr +i /home/immutible.txt";
    script_run "echo 'Immutible file' >> /tmp/immutible.txt";
    script_run "chattr +i /tmp/immutible.txt";
    # trigger SUSE.Linux.Events.NewFiles
    script_run "sudo echo 'new files' >> /etc/cron.hourly/newfiles.txt";
    script_run "sudo echo 'new files' >> /etc/cron.daily/newfiles.txt";
    script_run "sudo echo 'new files' >> /etc/cron.weekly/newfiles.txt";
    # trigger SUSE.Linux.Events.NewFilesNoOwner
    script_run "echo 'No owner file' >> /home/noownerfile.txt";
    script_run "chown 9999:9999 /home/noownerfile.txt";
    script_run "echo 'No owner file' >> /tmp/noownerfile.txt";
    script_run "chown 9999:9999 /tmp/noownerfile.txt";
    # trigger SUSE.Linux.Events.NewHiddenFile
    script_run "mkdir /home/.newhiddendir";
    script_run "echo 'New hidden file' >> /home/.newhiddenfiles.txt";
    script_run "mkdir /tmp/.newhiddenfir";
    script_run "echo 'New hidden file' >> /tmp/.newhiddenfiles.txt";
    # trigger SUSE.Linux.Events.NewZeroSizeLogFile
    script_run "touch /var/log/newzerosizelog.txt";
    # trigger SUSE.Linux.Events.SSHLogin && SUSE.Linux.Events.SystemLogins SUSE.Linux.Events.ProcessStatuses
    zypper_call('in sshpass');
    script_run "sudo useradd -m user1";
    script_run "sudo useradd -m user2";
    script_run "echo 'user1:passwd1' | sudo chpasswd";
    script_run "echo 'user2:passwd2' | sudo chpasswd";
    script_run('sshpass -p \'passwd1\' ssh -o StrictHostKeyChecking=no user1@localhost whoami');
    script_run('sshpass -p \'passwd1\' ssh -o StrictHostKeyChecking=no user1@localhost date');
    script_run('sshpass -p \'passwd2\' ssh -o StrictHostKeyChecking=no user2@localhost whoami');
    script_run('sshpass -p \'passwd2\' ssh -o StrictHostKeyChecking=no user2@localhost date');
    script_run "sudo userdel -r user1";
    script_run "sudo userdel -r user2";
    # trigger SUSE.Linux.Events.Services
    script_run "systemctl status cron";
    script_run "systemctl restart cron";
    script_run "systemctl status cron";
    # trigger SUSE.Linux.Events.Packages
    zypper_call "in libexttextcat";
    zypper_call "in html2text";
    zypper_call "rm libexttextcat";
    zypper_call "rm html2text";
    sleep 15;
    # trigger SUSE.Linux.Events.SshAuthorizedKeys
    #script_run 'echo \'test event keys123@example\' >> .ssh/authorized_keys';
    #script_run 'echo \'test event keys456@example\' >> .ssh/authorized_keys';
    #script_run 'echo \'test event keys789@example\' >> .ssh/authorized_keys';
    #script_run 'cat .ssh/authorized_keys';
    # trigger SUSE.Linux.Events.TCPConnections
    script_run "nc localhost 8080";
    # trigger SUSE.Linux.Events.Timers
    #script_run "systemctl status snapper-timeline.timer";
    #script_run "systemctl restart snapper-timeline.timer";
    #script_run "systemctl status snapper-timeline.timer";
    # trigger SUSE.Linux.Events.UserAccount
    #script_run"";
    # trigger SUSE.Linux.Events.UserGroupMembershipUpdates
    #script_run"";

    # get client id
    my $clientid = script_output('velociraptor-client --api_config ~/api.config.yaml query \'SELECT *, os_info.hostname as Hostname, client_id FROM clients()\' | grep -oP \'"client_id": "\K.*(?=")\'', 120);

    # check for collected event on server
    sleep 90;
    foreach my $artifact (@artifacts) {
        my $path = "/var/tmp/velociraptor/clients/$clientid/monitoring/$artifact/";
        if (-d $path) {
            print "$path event logs present";
            script_run("ls $path | grep json");
        }
        else {
            print "$path event logs missing";
        }
    }

    # upload event logs
    script_run "tar cvpzf eventlogs.tgz /var/tmp/velociraptor/clients/$clientid/monitoring/";
    upload_logs('eventlogs.tgz');

    # skipping validation on s390x due to https://jira.suse.com/browse/SENS-122
    if (!is_s390x) {
        # search for SUSE.Linux.Events.ExecutableFiles
        script_output "grep -r -i genfile* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.ImmutableFile
        script_output "grep -r -i immutible* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.NewFiles
        script_output "grep -r -i newfiles* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.NewFilesNoOwner
        script_output "grep -r -i noownerfile* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.NewZeroSizeLogFile
        script_output "grep -r -i newzerosizelog* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.NewHiddenFile
        script_output "grep -r -i newhiddenfiles* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.Packages
        script_output "grep -r -i libexttextcat* /var/tmp/velociraptor/clients/$clientid/*";
        script_output "grep -r -i html2text* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.SSHLogin && SUSE.Linux.Events.SystemLogins && SUSE.Linux.Events.ProcessStatuses
        script_output "grep -r -i user1* /var/tmp/velociraptor/clients/$clientid/*";
        script_output "grep -r -i user2* /var/tmp/velociraptor/clients/$clientid/*";
        script_output "grep -r -i whoami* /var/tmp/velociraptor/clients/$clientid/*";
        script_output "grep -r -i date* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.Services
        script_output "grep -r -i cron* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.SshAuthorizedKeys
        #script_output "grep -r -i keys123\@example* /var/tmp/velociraptor/clients/$clientid/*";
        # search for SUSE.Linux.Events.TCPConnections
        script_output "grep -r -i localhost* /var/tmp/velociraptor/clients/$clientid/*";
    }

    #stop client cleanup
    systemctl "stop velociraptor-client";
    script_run "killall velociraptor-client";
    zypper_call "rm velociraptor-client";
    zypper_call "rm yq";
    zypper_call("rr yq");
}
1;
