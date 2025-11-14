use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none);

use sles4sap::aws_cli;

subtest '[aws_vpc_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Rocky'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_vpc_create(
        region => 'GranMax',
        cidr => 'Sirion',
        job_id => 'Hijet');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-vpc/ } @calls), 'Command create-vpc');
    ok(($res eq 'Rocky'), "Result is '$res' expected to be 'Rocky'");
};


subtest '[aws_vpc_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Rocky'; });

    my $res = aws_vpc_get_id(
        region => 'Taft',
        job_id => 'Atrai');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-vpcs/ } @calls), 'Command describe-vpcs');
    ok(($res eq 'Rocky'), "Result is '$res' expected to be 'Rocky'");
};


subtest '[aws_vpc_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Rocky'; });
    $awscli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = aws_vpc_delete(
        region => 'GranMax',
        vpc_id => 'Hijet');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-vpc/ } @calls), 'Command delete-vpc');
    ok(($ret eq 42), "Return expected 42 get $ret");
};


subtest '[aws_security_group_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Clarity'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_security_group_create(
        region => 'Ascot',
        group_name => 'Acty',
        description => 'Ballade',
        vpc_id => 'Capa',
        job_id => 'CityJazz');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-security-group/ } @calls), 'Command create-security-group');
    ok(($res eq 'Clarity'), "Result is '$res' expected to be 'Clarity'");
};


subtest '[aws_security_group_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Clarity'; });
    $awscli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = aws_security_group_delete(region => 'Cosmo', job_id => 'Civic');


    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-security-group/ } @calls), 'Command delete-security-group');
    ok(($ret eq 42), "Return expected 42 get $ret");
};


subtest '[aws_security_group_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Quint'; });

    my $res = aws_security_group_get_id(region => 'CR-X', job_id => 'CR-Z');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-security-groups/ } @calls), 'Command describe-security-groups');
    ok(($res eq 'Quint'), "Result is '$res' expected to be 'Quint'");
};

subtest '[aws_security_group_authorize_ingress]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    aws_security_group_authorize_ingress(
        sg_id => 'Legend',
        protocol => 'Today',
        port => 'Concerto',
        cidr => 'NSX',
        region => 'Beat');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 authorize-security-group-ingress/ } @calls), 'Command authorize-security-group-ingress');
};

subtest '[aws_ssh_key_pair_import]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    aws_ssh_key_pair_import(
        ssh_key => 'Carol',
        pub_key_path => 'Bongo'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 import-key-pair/ } @calls), 'Command import-key-pair');
    ok((any { /.*key-name.*Carol/ } @calls), 'ssh_key parameter is in command');
    ok((any { /.*public-key.*Bongo/ } @calls), 'pub_key_path parameter is in command');
};

subtest '[aws_subnet_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'subnet-123'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_subnet_create(
        region => 'Ascot',
        cidr => '10.0.1.0/24',
        vpc_id => 'vpc-12345',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-subnet/ } @calls), 'Command create-subnet');
    ok((any { /aws ec2 create-tags/ } @calls), 'Command create-tags');
    ok(($res eq 'subnet-123'), "Result is '$res' expected to be 'subnet-123'");
};

subtest '[aws_subnet_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'subnet-123'; });

    my $res = aws_subnet_get_id(
        region => 'Beat',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-subnets/ } @calls), 'Command describe-subnets');
    ok(($res eq 'subnet-123'), "Result is '$res' expected to be 'subnet-123'");
};

subtest '[aws_subnet_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_run => sub { push @calls, $_[0]; return 42; });
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'subnet-123'; });

    my $ret = aws_subnet_delete(
        region => 'Beat',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-subnet/ } @calls), 'Command delete-subnets');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[aws_internet_gateway_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'igw-123'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_internet_gateway_create(
        region => 'Ascot',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-internet-gateway/ } @calls), 'Command create-internet-gateway');
    ok((any { /aws ec2 create-tags/ } @calls), 'Command create-tags');
    ok(($res eq 'igw-123'), "Result is '$res' expected to be 'igw-123'");
};

subtest '[aws_internet_gateway_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'igw-123'; });

    my $res = aws_internet_gateway_get_id(
        region => 'Taft',
        job_id => '67890');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-internet-gateways/ } @calls), 'Command describe-internet-gateways');
    ok(($res eq 'igw-123'), "Result is '$res' expected to be 'igw-123'");
};

subtest '[aws_internet_gateway_attach]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    aws_internet_gateway_attach(
        vpc_id => 'vpc-12345',
        igw_id => 'igw-abcde',
        region => 'Ascot'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 attach-internet-gateway/ } @calls), 'Command attach-internet-gateway');
};

subtest '[aws_internet_gateway_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'igw-123'; });
    my $script_run_count = 0;
    $awscli->redefine(script_run => sub {
            push @calls, $_[0];
            $script_run_count++;
            return $script_run_count == 1 ? 0 : 42;
    });

    my $ret = aws_internet_gateway_delete(
        vpc_id => 'vpc-12345',
        job_id => '67890',
        region => 'Ascot');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 detach-internet-gateway/ } @calls), 'Command detach-internet-gateway');
    ok((any { /aws ec2 delete-internet-gateway/ } @calls), 'Command delete-internet-gateway');
    ok(($ret eq 42), "Return expected 42 get $ret");
    is($script_run_count, 2, "script_run called twice");
};

subtest '[aws_route_table_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'rtb-123'; });

    my $res = aws_route_table_create(
        region => 'Beat',
        vpc_id => 'vpc-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-route-table/ } @calls), 'Command create-route-table');
    ok(($res eq 'rtb-123'), "Result is '$res' expected to be 'rtb-123'");
};

subtest '[aws_route_table_associate]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    aws_route_table_associate(
        subnet_id => 'subnet-12345',
        route_table_id => 'rtb-abcde',
        region => 'us-west-1'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 associate-route-table/ } @calls), 'Command associate-route-table');
};

subtest '[aws_route_table_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'MX-5Miata Altezza'; });
    my $script_run_count = 0;
    $awscli->redefine(script_run => sub {
            push @calls, $_[0];
            $script_run_count++;
            return $script_run_count == 1 ? 0 : 42;
    });

    my $ret = aws_route_table_delete(vpc_id => 'Supra', region => 'HondaNSX');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-route-table/ } @calls), 'Command delete-route-table');
    ok(($ret eq 42), "Return expected 42 get $ret");
    is($script_run_count, 2, "script_run called twice");
};

subtest '[aws_route_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    aws_route_create(
        route_table_id => 'rtb-12345',
        destination_cidr_block => '0.0.0.0/0',
        igw_id => 'igw-abcde',
        region => 'us-west-1'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-route/ } @calls), 'Command create-route');
};

subtest '[aws_vm_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub {
            push @calls, $_[0];
            # first call is describe-images, second is run-instances
            return @calls == 1 ? 'ami-123' : 'i-123';
    });

    my $res = aws_vm_create(
        instance_type => 'Micra',
        image_name => 'Sentra',
        owner => 'Elgrand',
        subnet_id => 'Pathfinder',
        sg_id => 'Serena',
        ssh_key => 'Altima',
        region => 'Almera',
        job_id => 'Sylphy'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-images/ } @calls), 'Command describe-images');
    ok((any { /aws ec2 run-instances/ } @calls), 'Command run-instances');
    ok(($res eq 'i-123'), "Result is '$res' expected to be 'i-123'");
};

subtest '[aws_vm_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'i-123'; });

    my $res = aws_vm_get_id(
        region => 'Almera',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok(($res eq 'i-123'), "Result is '$res' expected to be 'i-123'");
};

subtest '[aws_vm_wait_status_ok]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_retry => sub { push @calls, $_[0]; return; });

    aws_vm_wait_status_ok(
        instance_id => 'i-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok((any { /grep 'running'/ } @calls), 'grep running is in command');
};

subtest '[aws_get_ip_address]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return '1.2.3.4'; });

    my $res = aws_get_ip_address(
        instance_id => 'i-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok(($res eq '1.2.3.4'), "Result is '$res' expected to be '1.2.3.4'");
};

subtest '[aws_vm_terminate]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    my @calls;
    my $script_run_count = 0;
    $awscli->redefine(script_run => sub {
            push @calls, $_[0];
            $script_run_count++;
            return $script_run_count == 1 ? 0 : 42;
    });

    my $ret = aws_vm_terminate(
        region => 'us-west-1',
        instance_id => 'i-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 terminate-instances/ } @calls), 'Command terminate-instances');
    ok((any { /aws ec2 wait instance-terminated/ } @calls), 'Command wait instance-terminated');
    ok(($ret eq 42), "Return expected 42 get $ret");
    is($script_run_count, 2, "script_run called twice");
};

done_testing;
