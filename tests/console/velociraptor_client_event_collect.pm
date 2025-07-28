# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: velociraptor-client
# Summary: install velociraptor-client and collect events on server
# Maintainer: Gayane Osipyan <gosipyan@suse.com>

use base "consoletest";
use testapi;
use version_utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
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

    if (is_sle) {
        # beta1 has dependency issue will enable with beta2
        if (is_sle('=16') || $sp_version == '16') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_16/ sensor");
        }
        if (is_sle('=15-SP7') || $sp_version == '15.7') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP7/ sensor");
        }
        elsif (is_sle('=15-SP6') || $sp_version == '15.6') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP6/ sensor");
        }
        elsif (is_sle('=15-SP5') || $sp_version == '15.5') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP5/ sensor");
        }
        elsif (is_sle('=15-SP4') || $sp_version == '15.4') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP4/ sensor");
        }
        elsif (is_sle('=12-SP5') || $sp_version == '12.5') {
            zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_12_SP5/ sensor");
        }

    }
    elsif (is_leap('>=15.3')) {
        zypper_call("ar -f --no-gpgcheck https://download.opensuse.org/repositories/security:/sensor/openSUSE_Leap_15.4/ sensor");
    }
    elsif (is_tumbleweed) {
        zypper_call("ar -f --no-gpgcheck https://download.opensuse.org/repositories/security:/sensor/openSUSE_Tumbleweed/ sensor");
    }
    else {
        record_info('Skipped', 'Missing source repository', result => 'softfail');
    }


    # velociraptor client install
    zypper_call("lr -U");
    zypper_call("in --from sensor velociraptor-client");
    my $client_version = script_output("zypper info velociraptor-client | grep Source | cut -f 2 -d\":\" | tr -d \" \"");
    print "ClientVersion:$client_version";
    zypper_call "up velociraptor-client";
    zypper_call "info velociraptor-client";
    systemctl "enable velociraptor-client";
    systemctl "is-enabled velociraptor-client";

    # generate config files
    script_output('cat > init-config.json <<EOF
{
  "defaults": {
    "event_max_wait": 1,
    "event_max_wait_jitter": 1,
    "event_change_notify_all_clients": true
  },
  "Client": {
    "max_poll": 1,
    "max_poll_std": 1,
    "min_poll": 1,
    "default_max_wait": 1
  }
}
EOF');

    script_run("velociraptor-client config generate --merge_file=init-config.json > server.conf");
    background_script_run("velociraptor-client frontend -v --config server.conf > /dev/null 2>&1 &");
    script_run("velociraptor-client config client --config server.conf > /etc/velociraptor/client.config");
    script_run("sed -i 's/VELOCIRAPTOR_CLIENT_OPTS=\"\"/VELOCIRAPTOR_CLIENT_OPTS=\"-v\"' /etc/sysconfig/velociraptor-client");
    # generate server api config
    assert_script_run("velociraptor-client --config server.conf config api_client --name admin --role administrator api.config.yaml");
    # get client info from server
    sleep 10;
    assert_script_run("velociraptor-client --api_config ~/api.config.yaml query 'SELECT * FROM info()'");

    # add client monitoring
    my @artifacts = qw(SUSE.Linux.Events.Crontab SUSE.Linux.Events.DNS SUSE.Linux.Events.ExecutableFiles SUSE.Linux.Events.ImmutableFile SUSE.Linux.Events.NewFiles SUSE.Linux.Events.NewFilesNoOwner SUSE.Linux.Events.NewHiddenFile SUSE.Linux.Events.NewZeroSizeLogFile SUSE.Linux.Events.Packages SUSE.Linux.Events.ProcessStatuses SUSE.Linux.Events.SSHLogin SUSE.Linux.Events.Services SUSE.Linux.Events.SshAuthorizedKeys SUSE.Linux.Events.SystemLogins SUSE.Linux.Events.TCPConnections SUSE.Linux.Events.Timers SUSE.Linux.Events.UserAccount SUSE.Linux.Events.UserGroupMembershipUpdates);
    foreach my $artifact (@artifacts) {
        if ($artifact == 'SUSE.Linux.Events.Packages' || $artifact == 'SUSE.Linux.Events.SshAuthorizedKeys') {
            script_output("velociraptor-client --api_config ~/api.config.yaml query 'SELECT add_client_monitoring(artifact=\"$artifact\", parameters=dict(period=\"10\")) FROM scope()' > /dev/null");

        }
        else {
            script_output("velociraptor-client --api_config ~/api.config.yaml query 'SELECT add_client_monitoring(artifact=\"$artifact\") FROM scope()' > /dev/null");
        }
    }

    # start client
    systemctl("restart velociraptor-client");
    systemctl("status velociraptor-client");
    sleep 10;
    # trigger SUSE.Linux.Events.DNS
    script_run("host localhost");
    script_run("nslookup localhost");
    script_run("dig example.com");
    # trigger SUSE.Linux.Events.ExecutableFiles
    script_run("echo 'Client Event exec' >> /home/genfileh.sh");
    script_run("chmod +x /home/genfileh.sh");
    script_run("echo 'Client Event exec' >> /tmp/genfilet.sh");
    script_run("chmod +x /tmp/genfilet.sh");
    # trigger SUSE.Linux.Events.ImmutableFile
    script_run("echo 'Immutible file' >> /home/immutible.txt");
    script_run("chattr +i /home/immutible.txt");
    script_run("echo 'Immutible file' >> /tmp/immutible.txt");
    script_run("chattr +i /tmp/immutible.txt");
    # trigger SUSE.Linux.Events.NewFiles
    script_run("sudo echo 'new files' >> /etc/cron.hourly/newfiles.txt");
    script_run("sudo echo 'new files' >> /etc/cron.daily/newfiles.txt");
    script_run("sudo echo 'new files' >> /etc/cron.weekly/newfiles.txt");
    # trigger SUSE.Linux.Events.NewFilesNoOwner
    script_run("echo 'No owner file' >> /home/noownerfile.txt");
    script_run("chown 9999:9999 /home/noownerfile.txt");
    script_run("echo 'No owner file' >> /tmp/noownerfile.txt");
    script_run("chown 9999:9999 /tmp/noownerfile.txt");
    # trigger SUSE.Linux.Events.NewHiddenFile
    script_run("mkdir /home/.newhiddendir");
    script_run("echo 'New hidden file' >> /home/.newhiddenfiles.txt");
    script_run("mkdir /tmp/.newhiddenfir");
    script_run("echo 'New hidden file' >> /tmp/.newhiddenfiles.txt");
    # trigger SUSE.Linux.Events.NewZeroSizeLogFile
    script_run("touch /var/log/newzerosizelog.txt");
    # trigger SUSE.Linux.Events.Packages
    # add repository
    if (is_sle('=12-SP5')) {
        zypper_call("ar -f --no-gpgcheck https://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12/standard/ backports-12");
    }
    elsif (is_tumbleweed) {
        if (is_ppc64le) {
            zypper_call("ar -f --no-gpgcheck https://download.opensuse.org/repositories/network/openSUSE_Factory_PowerPC/ factory");
        }
        else {
            zypper_call("ar -f --no-gpgcheck https://download.opensuse.org/repositories/network/openSUSE_Tumbleweed/ factory"); }
    }
    else {
        zypper_call("ar -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Factory:/Head/standard/ factory");
    }
    zypper_call('in sshpass');
    # trigger SUSE.Linux.Events.SSHLogin && SUSE.Linux.Events.SystemLogins SUSE.Linux.Events.ProcessStatuses
    script_run("sudo useradd -m user1");
    script_run("sudo useradd -m user2");
    script_run("echo 'user1:passwd1' | sudo chpasswd");
    script_run("echo 'user2:passwd2' | sudo chpasswd");
    script_output('sshpass -p \'passwd1\' ssh -o StrictHostKeyChecking=no user1@localhost whoami');
    script_output('sshpass -p \'passwd1\' ssh -o StrictHostKeyChecking=no user1@localhost date');
    script_output('sshpass -p \'passwd2\' ssh -o StrictHostKeyChecking=no user2@localhost whoami');
    script_output('sshpass -p \'passwd2\' ssh -o StrictHostKeyChecking=no user2@localhost date');
    script_run("sudo userdel -r user1");
    script_run("sudo userdel -r user2");
    # trigger SUSE.Linux.Events.Services
    script_run("systemctl status cron");
    script_run("systemctl restart cron");
    script_run("systemctl status cron");
    # trigger SUSE.Linux.Events.SshAuthorizedKeys
    script_run('echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArandomstring test@testkey" >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys');
    # trigger SUSE.Linux.Events.TCPConnections
    script_run("nc localhost 8080");
    # trigger SUSE.Linux.Events.Timers
    script_output("echo -e \"[Unit]\nDescription=Simple Task\n\n[Service]\nType=oneshot\nExecStart=/bin/bash -c 'date >> /tmp/mytimer.log'\" | tee /etc/systemd/system/mytimer.service");
    script_output("echo -e \"[Unit]\nDescription=Runs mytimer.service every minute\n\n[Timer]\nOnUnitActiveSec=1m\nOnBootSec=1m\nPersistent=true\n\n[Install]\nWantedBy=timers.target\" | tee /etc/systemd/system/mytimer.timer");
    script_run("systemctl daemon-reload");
    script_run("systemctl enable --now mytimer.timer");
    script_run("systemctl list-timers --all");
    script_run("systemctl status mytimer.timer");
    script_run("systemctl restart mytimer.timer");
    # trigger SUSE.Linux.Events.UserAccount
    script_run("groupadd testgroup && useradd -m -s /bin/bash -G testgroup testuser");
    # trigger SUSE.Linux.Events.UserGroupMembershipUpdates
    script_run("groupadd newgroup");
    script_run("usermod -aG newgroup testuser");
    script_run("userdel -r testuser && groupdel testgroup");
    # trigger SUSE.Linux.Events.Crontab
    script_run("(crontab -l 2>/dev/null; echo \"* * * * * echo 'Test cronevent $(date)' >> /tmp/cronevent-test.log\") | crontab -");
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
    script_run("tar cvpzf eventlogs.tgz /var/tmp/velociraptor/clients/$clientid/");
    upload_logs('eventlogs.tgz');

    # search for SUSE.Linux.Events.ExecutableFiles
    script_run("grep -r -i genfile* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.NewFiles
    script_run("grep -r -i newfiles* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.NewFilesNoOwner
    script_run("grep -r -i noownerfile* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.NewZeroSizeLogFile
    script_run("grep -r -i newzerosizelog* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.NewHiddenFile
    script_run("grep -r -i newhiddenfiles* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.Packages
    script_run("grep -r -i sshpass* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.SSHLogin && SUSE.Linux.Events.SystemLogins && SUSE.Linux.Events.ProcessStatuses
    script_run("grep -r -i user1* /var/tmp/velociraptor/clients/$clientid/*");
    script_run("grep -r -i user2* /var/tmp/velociraptor/clients/$clientid/*");
    script_run("grep -r -i whoami* /var/tmp/velociraptor/clients/$clientid/*");
    script_run("grep -r -i date* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.Services
    script_run("grep -r -i cron* /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.SshAuthorizedKeys
    script_run("grep -r -i test\@testkey* /var/tmp/velociraptor/clients/$clientid/*");
    # search SUSE.Linux.Events.Timers
    script_run("grep -r -i mytimer.timer /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Crontab
    script_run("grep -r -i cronevent /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.UserGroupMembershipUpdates
    script_run("grep -r -i testgroup /var/tmp/velociraptor/clients/$clientid/*");
    # search for SUSE.Linux.Events.UserAccount
    script_run("grep -r -i testuser /var/tmp/velociraptor/clients/$clientid/*");
    # The eBPF based plugins don't get built on SLE12SP5
    if (!is_sle('=12-SP5')) {
        # search for SUSE.Linux.Events.ImmutableFile
        script_run("grep -r -i immutible* /var/tmp/velociraptor/clients/$clientid/*");
        # search for SUSE.Linux.Events.TCPConnections
        script_run("grep -r -i localhost* /var/tmp/velociraptor/clients/$clientid/*");
        # search for SUSE.Linux.Events.DNS
        script_run("grep -r -i example.com* /var/tmp/velociraptor/clients/$clientid/*");
    }
    #stop client cleanup
    systemctl("stop velociraptor-client");
    script_run("killall velociraptor-client");
    zypper_call("rm velociraptor-client");
    zypper_call("rr factory");
}
1;
