# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon ec2
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::ec2;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON 'decode_json';
use testapi;
use utils qw(random_string script_retry);
use version_utils qw(is_transactional is_sle);
use Utils::Architectures qw(is_aarch64);
use publiccloud::utils qw(is_byos pc_data_url);
use publiccloud::zypper qw(pc_zypper_call);
use publiccloud::aws_client;
use publiccloud::ssh_interactive 'select_host_console';

has ssh_key_pair => undef;
use constant SSH_KEY_PEM => 'QA_SSH_KEY.pem';

my $EC2_CW_LOGS = [
    {
        log_group => '/ec2/logs/dmesg',
        filename => 'ec2__logs__dmesg.txt',
    }
];

my $curl_cmd = is_sle("=12-SP5") ? "wget -O" : "curl -sLo";

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::aws_client->new());
    $self->provider_client->init();
}

sub find_img {
    my ($self, $name) = @_;

    $name = $self->prefix . '-' . $name;

    my $ownerId = get_var('PUBLIC_CLOUD_EC2_ACCOUNT_ID', script_output('aws sts get-caller-identity --query "Account" --output text'));
    my $out = script_output("aws ec2 describe-images  --filters 'Name=name,Values=$name' --owners '$ownerId'");
    if ($out =~ /"ImageId":\s+"([^"]+)"/) {
        return $1;
    }
    return;
}

# Returns true if key is already created in EC2 otherwise tries 10 times to create it and then fails
# If the subroutine manager to create key pair in EC2 it stores it in $self->ssh_key_pair

sub create_keypair {
    my ($self, $prefix) = @_;

    return 1 if (script_run('test -s ' . SSH_KEY_PEM) == 0);

    for my $i (0 .. 9) {
        my $key_name = $prefix . "_" . $i;
        my $cmd = "aws ec2 create-key-pair --key-name '" . $key_name
          . "' --query 'KeyMaterial' --output text > " . SSH_KEY_PEM;
        my $ret = script_run($cmd);
        if (defined($ret) && $ret == 0) {
            assert_script_run('chmod 0400 ' . SSH_KEY_PEM);
            $self->ssh_key_pair($key_name);
            return 1;
        }
    }
    return 0;
}

sub delete_keypair {
    my $self = shift;
    my $name = shift || $self->ssh_key;

    return unless $name;

    assert_script_run("aws ec2 delete-key-pair --key-name " . $name);
    $self->ssh_key(undef);
}

sub upload_img {
    my ($self, $file) = @_;

    die("Create key-pair failed") unless ($self->create_keypair($self->prefix . time));

    # AMI of image to use for helper VM to create/build the image on CSP.
    my $helper_ami_id = get_var('PUBLIC_CLOUD_EC2_UPLOAD_AMI');

    die('Please specify PUBLIC_CLOUD_EC2_UPLOAD_AMI variable.') unless (defined($helper_ami_id));

    my ($img_name) = $file =~ /([^\/]+)$/;
    my $img_arch = get_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    my $sec_group = get_var('PUBLIC_CLOUD_EC2_UPLOAD_SECGROUP');
    my $vpc_subnet = get_var('PUBLIC_CLOUD_EC2_UPLOAD_VPCSUBNET');
    my $instance_type = get_required_var('PUBLIC_CLOUD_EC2_UPLOAD_INSTANCE_TYPE');

    if (!$sec_group) {
        $sec_group = script_output("aws ec2 describe-security-groups --output text "
              . "--region " . $self->provider_client->region . " "
              . "--filters 'Name=group-name,Values=tf-sg' "
              . "--query 'SecurityGroups[0].GroupId'"
        );
        $sec_group = "" if ($sec_group eq "None");
    }
    if (!$vpc_subnet) {
        my $vpc_id = script_output("aws ec2 describe-vpcs --output text "
              . "--region " . $self->provider_client->region . " "
              . "--filters 'Name=tag:Name,Values=tf-vpc' "
              . "--query 'Vpcs[0].VpcId'"
        );
        if ($vpc_id ne "None") {
            # Grab subnet with CidrBlock defined in https://gitlab.suse.de/qac/infra/-/blob/master/aws/tf/main.tf
            $vpc_subnet = script_output("aws ec2 describe-subnets --output text "
                  . "--region " . $self->provider_client->region . " "
                  . "--filters 'Name=vpc-id,Values=$vpc_id' 'Name=cidr-block,Values=10.11.4.0/22' "
                  . "--query 'Subnets[0].SubnetId'"
            );
            $vpc_subnet = "" if ($vpc_subnet eq "None");
        }
    }

    # ec2uploadimg will fail without this file, but we can have it empty
    # because we passing all needed info via params anyway
    assert_script_run('echo " " > /root/.ec2utils.conf');

    my @ec2_cmd = ("ec2uploadimg",
        "--access-id \$AWS_ACCESS_KEY_ID -s \$AWS_SECRET_ACCESS_KEY",
        "--backing-store ssd",
        "--grub2",
        "--machine",
        "'$img_arch'",
        "-n", $self->prefix . "-" . $img_name,
        "--virt-type hvm",
        "--sriov-support",
        "--ena-support",
        "--verbose",
        "--regions", $self->provider_client->region,
        "--ssh-key-pair", $self->ssh_key_pair,
        "--private-key-file", SSH_KEY_PEM,
        "-d 'OpenQA upload image'",
        "--wait-count 3",
        "--ec2-ami '$helper_ami_id'",
        "--type", $instance_type,
        "--user", $self->provider_client->username,
        "--boot-mode", get_var("PUBLIC_CLOUD_EC2_BOOT_MODE", "uefi-preferred"));

    push @ec2_cmd, "--use-root-swap" unless ((get_var('FLAVOR') =~ '-SAP-') || is_byos());
    push @ec2_cmd, "--security-group-ids '$sec_group'" if ($sec_group);
    push @ec2_cmd, "--vpc-subnet-id '$vpc_subnet'" if ($vpc_subnet);
    push @ec2_cmd, "'$file'";

    assert_script_run(join(" ", @ec2_cmd), timeout => 60 * 60);

    my $ami = $self->find_img($img_name);
    die("Cannot find image after upload!") unless $ami;
    script_run("aws ec2 create-tags --resources $ami --tags Key=pcw_ignore,Value=1") if (check_var('PUBLIC_CLOUD_KEEP_IMG', '1'));
    validate_script_output('aws ec2 describe-images --image-id ' . $ami, sub { /"EnaSupport":\s+true/ });
    record_info('INFO', "AMI: $ami");    # Show the ami-* number, could be useful
}

sub terraform_apply {
    my ($self, %args) = @_;
    my $confidential_compute = get_var('PUBLIC_CLOUD_CONFIDENTIAL_VM');
    $args{vars}->{enable_confidential_vm} = 'enabled' if $confidential_compute;
    $args{vars}->{ipv6_address_count} = get_var('PUBLIC_CLOUD_EC2_IPV6_ADDRESS_COUNT', 0);
    $args{vars}->{nitro_enclave} = "true" if check_var("PUBLIC_CLOUD_EC2_NITRO_ENCLAVE", "1");
    return $self->SUPER::terraform_apply(%args);
}

sub on_terraform_apply_timeout {
    my ($self) = @_;
}

sub upload_boot_diagnostics {
    my ($self, %args) = @_;
    $args{log_name} //= "console";

    my $instance_id = $self->get_terraform_output('.vm_name.value[]');
    return if (check_var('PUBLIC_CLOUD_SLES4SAP', 1));
    unless (defined($instance_id)) {
        record_info('UNDEF. diagnostics', 'upload_boot_diagnostics: on ec2, undefined instance');
        return;
    }
    my $asset_path = "/tmp/" . $args{log_name} . ".txt";
    script_run("aws ec2 get-console-output --latest --color=off --no-paginate --output text --instance-id $instance_id &> $asset_path", proceed_on_failure => 1);
    if (script_output("du $asset_path | cut -f1") < 8) {
        record_info("EMPTY", "The console log is empty. `cat $asset_path`:\n" . script_output("cat $asset_path"));
    } elsif (check_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'i3.large')) {
        record_info('UNSUPPORTED_INSTANCE', "The 'i3.large' instance doesn't support serial terminal.");
    } else {
        upload_logs("$asset_path", failok => 1);
    }

    $asset_path = "/tmp/console.jpg";
    script_run("timeout -k 5 150s aws ec2 get-console-screenshot --instance-id $instance_id | jq -r '.ImageData' | base64 --decode > $asset_path", timeout => 180);
    if (script_output("du $asset_path | cut -f1") < 8) {
        record_info('empty screenshot', 'The console screenshot is empty.');
        record_info('Asset path', "$asset_path - " . script_output("cat $asset_path"));
    } else {
        upload_logs("$asset_path", failok => 1);
    }
}

sub img_proof {
    my ($self, %args) = @_;

    $args{instance_type} //= 't3a.large';
    $args{user} //= $self->provider_client->username;
    $args{provider} //= 'ec2';
    $args{ssh_private_key_file} //= SSH_KEY_PEM;
    $args{key_name} //= $self->ssh_key;

    return $self->run_img_proof(%args);
}

sub teardown {
    my ($self, $args) = @_;

    $self->SUPER::teardown();
    $self->delete_keypair();
    return 1;
}

sub describe_instance {
    my ($self, $instance_id, $query) = @_;
    my $region = get_required_var('PUBLIC_CLOUD_REGION');
    chomp($query);
    return script_output("aws ec2 describe-instances --filter Name=instance-id,Values=$instance_id --region $region | jq -r '.Reservations[0].Instances[0]" . $query . "'", quiet => 1);
}

sub get_state_from_instance {
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();
    return $self->describe_instance($instance_id, '.State.Name');
}

sub get_public_ip {
    my ($self) = @_;
    my $instance_id = $self->get_terraform_output('.vm_name.value[]');
    return $self->describe_instance($instance_id, '.PublicIpAddress');
}

sub stop_instance
{
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();
    my $attempts = 60;

    die("Outdated instance object") if ($instance->public_ip ne $self->get_public_ip());

    assert_script_run('aws ec2 stop-instances --instance-ids ' . $instance_id, quiet => 1);

    while ($self->get_state_from_instance($instance) ne 'stopped' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $instance_id") unless ($attempts > 0);
}

sub start_instance {
    my ($self, $instance, %args) = @_;
    my $attempts = 60;
    my $instance_id = $instance->instance_id();

    my $state = $self->describe_instance($instance_id, '.State.Name');
    die("Try to start a running instance") if ($state ne 'stopped');

    assert_script_run("aws ec2 start-instances --instance-ids $instance_id", quiet => 1);
    sleep 1;    # give some time to update public_ip
    my $public_ip;
    while (!defined($public_ip) && $attempts-- > 0) {
        $public_ip = $self->get_public_ip();
    }
    die("Unable to get new public IP") unless ($public_ip);
    $instance->public_ip($public_ip);
}

sub change_instance_type {
    my ($self, $instance, $instance_type) = @_;
    my $instance_id = $instance->instance_id();
    die "Instance type is already $instance_type" if ($self->describe_instance($instance_id, '.InstanceType') eq $instance_type);
    assert_script_run("aws ec2 modify-instance-attribute --instance-id $instance_id --instance-type '{\"Value\": \"$instance_type\"}'");
    die "Failed to change instance type to $instance_type" if ($self->describe_instance($instance_id, '.InstanceType') ne $instance_type);
}

sub query_metadata {
    my ($self, $instance, %args) = @_;
    my $ifNum = $args{ifNum};
    my $addrCount = $args{addrCount};

    # Cloud metadata service API is reachable at local destination
    # 169.254.169.254 in case of all public cloud providers.
    my $pc_meta_api_ip = '169.254.169.254';

    my $access_token = $instance->ssh_script_output(qq(curl -sw "\\n" -X PUT http://$pc_meta_api_ip/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds:60"));
    record_info("DEBUG", $access_token);
    my $query_meta_ipv4_cmd = qq(curl -sw "\\n" -H "X-aws-ec2-metadata-token: $access_token" "http://$pc_meta_api_ip/latest/meta-data/local-ipv4");
    my $data = $instance->ssh_script_output($query_meta_ipv4_cmd);

    die("Failed to get data from metadata server") unless length($data);
    return $data;
}

sub _disable_and_stop_ec2_cloudwatch_agent {
    my ($self, $instance) = @_;

    # systemctl is-enabled exits 4 when the unit file does not exist at all.
    return if $instance->ssh_script_run("sudo systemctl is-enabled amazon-cloudwatch-agent") == 4;

    if ($instance->ssh_script_run("sudo systemctl is-active amazon-cloudwatch-agent") == 0) {
        my $instance_id = $instance->instance_id;
        my $region = $self->provider_client->region;
        my $token = random_string(6) . '-vamoosed';
        $instance->ssh_assert_script_run("echo 'openqa-cloudwatch-fence-$token' | sudo tee -a /var/log/dmesg");
        script_retry(
            "aws logs get-log-events --region '$region' --log-group-name '/ec2/logs/dmesg' " .
              "--log-stream-name '$instance_id' --no-start-from-head --limit 10 " .
              "--query 'events[*].message' --output text | grep -q '$token'",
            retry => 6, delay => 5, timeout => 30, die => 0
        );
        $instance->ssh_script_run("sudo systemctl disable --now amazon-cloudwatch-agent");
    } else {
        $instance->ssh_script_run("sudo systemctl disable amazon-cloudwatch-agent");
    }
}

sub _fetch_ec2_cloudwatch_log_events {
    my ($self, %args) = @_;

    my $log_group = $args{log_group};
    my $log_stream = $args{log_stream};
    my $log_filename = $args{log_filename};

    my $end_time = int(time() * 1000);

    my $next_token;
    my $prev_token = "";

    my $cli_timeout = 5 * 60;    # Timeout for each CLI call, set to 5 minutes
    my $loop_eol = time() + (2 * $cli_timeout * 10); # Loop end-of-life to prevent infinite loops in case of unexpected CLI behavior. 2 cli calls per loop, so 2x cli timeout with maximum of 10 loops.

    while (time() < $loop_eol) {
        my $cmd =
          "aws logs get-log-events " .
          "--log-group-name '$log_group' " .
          "--log-stream-name '$log_stream' " .
          "--start-from-head ";

        $cmd .= "--next-token '$next_token' " if $next_token;

        assert_script_run(
            "$cmd "
              . "--end-time $end_time "
              . "--query 'events[*].[timestamp,message]' "
              . "--output text >> '$log_filename'",
            timeout => $cli_timeout
        );

        my $token_cmd =
          "$cmd "
          . "--end-time $end_time "
          . "--query 'nextForwardToken' "
          . "--output text";

        my $new_token = script_output($token_cmd, timeout => $cli_timeout);

        last if !$new_token || $new_token eq $prev_token;

        $prev_token = $new_token;
        $next_token = $new_token;
    }
}

sub _download_ec2_cloudwatch_logs {
    my ($self, $instance) = @_;

    my $instance_id = $instance->instance_id;

    $self->_disable_and_stop_ec2_cloudwatch_agent($instance);

    for my $entry (@$EC2_CW_LOGS) {

        my $log_group = $entry->{log_group};
        my $log_filename = $entry->{filename};
        my $log_stream = $instance_id;

        my $next_token;
        my $prev_token = "";

        my $describe_cmd =
          "aws logs describe-log-streams " .
          "--log-group-name '$log_group' " .
          "--log-stream-name-prefix '$log_stream' " .
          "--query 'logStreams[?logStreamName==`$log_stream`].logStreamName' " .
          "--output text";
        my $existing_log_stream = script_output($describe_cmd, timeout => 300, proceed_on_failure => 1);
        chomp $existing_log_stream;
        unless ($existing_log_stream && $existing_log_stream eq $log_stream) {
            record_info("EC2 CloudWatch Logs", "Log stream '$log_stream' does not exist in log group '$log_group'. Skipping download for this log group.");
            next;
        }

        assert_script_run(": > '$log_filename'");

        $self->_fetch_ec2_cloudwatch_log_events(
            log_group => $log_group,
            log_stream => $log_stream,
            log_filename => $log_filename,
        );


        upload_logs($log_filename);

        assert_script_run(
            "aws logs delete-log-stream " .
              "--log-group-name '$log_group' " .
              "--log-stream-name '$log_stream'"
        );
    }
}

# Write dmesg output to /var/log/dmesg so it can be collected as a file-based log source for centralized logging.
sub _install_dmesg_capture_to_log
{
    my ($self, $instance) = @_;

    my $svc_file = 'dmesg-capture.service';
    my $svc_target = '/etc/systemd/system/' . $svc_file;
    $instance->ssh_assert_script_run(
        "sudo $curl_cmd $svc_target " . pc_data_url("publiccloud/$svc_file") . " && " .
          "sudo systemctl daemon-reload && " .
          "sudo systemctl enable --now $svc_file"
    );

    my $logrotate_file = 'dmesg-capture-logrotate.conf';
    my $logrotate_target = '/etc/logrotate.d/dmesg';
    $instance->ssh_assert_script_run(
        "sudo $curl_cmd $logrotate_target " . pc_data_url("publiccloud/$logrotate_file") . " && " .
          "sudo logrotate -d $logrotate_target"
    );
}

sub _install_ec2_cloudwatch_agent
{
    my ($self, $instance) = @_;

    $self->_install_dmesg_capture_to_log($instance);

    my $arch = is_aarch64() ? "arm64" : "amd64";

    my $rpm_file = "amazon-cloudwatch-agent.rpm";
    my $gpg_file = "amazon-cloudwatch-agent.gpg";

    my $download_directory = "/root";

    $instance->ssh_assert_script_run("sudo $curl_cmd $download_directory/$gpg_file https://amazoncloudwatch-agent.s3.amazonaws.com/assets/amazon-cloudwatch-agent.gpg");

    $instance->ssh_assert_script_run("sudo gpg --batch --status-fd=1 --import $download_directory/$gpg_file 2>&1");

    $instance->ssh_assert_script_run("sudo $curl_cmd $download_directory/$rpm_file.sig https://amazoncloudwatch-agent.s3.amazonaws.com/suse/$arch/latest/amazon-cloudwatch-agent.rpm.sig");
    $instance->ssh_assert_script_run("sudo $curl_cmd $download_directory/$rpm_file https://amazoncloudwatch-agent.s3.amazonaws.com/suse/$arch/latest/amazon-cloudwatch-agent.rpm");
    $instance->ssh_assert_script_run(
        "sudo gpg --verify $download_directory/$rpm_file.sig $download_directory/$rpm_file 2>&1 | grep 'Good signature'",
        fail_message => "GPG signature verification failed for the downloaded RPM package."
    );

    if (is_transactional) {
        $instance->ssh_assert_script_run(
            cmd => "sudo transactional-update run sh -c 'rpm -Uvh --noscripts $download_directory/$rpm_file'",
            timeout => 300
        );
        $instance->softreboot();
    } else {
        if (is_sle(">12-SP5")) {
            pc_zypper_call($instance, "install --no-recommends --allow-unsigned-rpm $download_directory/$rpm_file");
        } else {
            $instance->ssh_assert_script_run("sudo rpm -Uvh $download_directory/$rpm_file");
        }
    }

    $instance->ssh_assert_script_run("sudo rm -f $download_directory/$rpm_file $download_directory/$rpm_file.sig $download_directory/$gpg_file");

    my $cfg_file = 'cloudwatch_config.json';
    my $cfg_target = '/opt/aws/amazon-cloudwatch-agent/etc/' . $cfg_file;
    $instance->ssh_assert_script_run("sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc");
    $instance->ssh_assert_script_run("sudo $curl_cmd $cfg_target " . pc_data_url("publiccloud/$cfg_file"));
    $instance->ssh_assert_script_run(
        "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl " .
          "-a fetch-config " .
          "-m ec2 " .
          "-c file:$cfg_target " .
          "-s"
    );
    $instance->ssh_assert_script_run("sudo systemctl enable --now amazon-cloudwatch-agent");
    $instance->ssh_script_retry("sudo systemctl is-active amazon-cloudwatch-agent");
}

sub initialize_logging {
    my ($self, $instance) = @_;
    $self->upload_boot_diagnostics(log_name => "console-beginning");
    record_info('Logging', 'Initializing logging for EC2 instance');
    $self->_install_ec2_cloudwatch_agent($instance);
}

sub finalize_logging {
    my ($self, $instance) = @_;
    $self->upload_boot_diagnostics(log_name => "console-end");
    record_info('Logging', 'Finalizing logging for EC2 instance');
    $self->_download_ec2_cloudwatch_logs($instance);
}
1;
