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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Rocky'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_vpc_create(
        region => 'GranMax',
        cidr => 'Sirion',
        tags => {openqa_var_job_id => 'Hijet'});

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-vpc/ } @calls), 'Command create-vpc');
    ok((any { /tag-specifications/ } @calls), 'Tag specifications present');
    ok((any { /\{Key=openqa_var_job_id,Value=Hijet\}/ } @calls), 'Tag passed to tag-specifications');
    ok(($res eq 'Rocky'), "Result is '$res' expected to be 'Rocky'");
};

subtest '[aws_vpc_create] no tags' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Rocky'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_vpc_create(
        region => 'GranMax',
        cidr => 'Sirion');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-vpc/ } @calls), 'Command create-vpc');
    ok((none { /aws ec2 create-tags/ } @calls), 'No create-tags without tags');
    ok(($res eq 'Rocky'), "Result is '$res' expected to be 'Rocky'");
};


subtest '[aws_vpc_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Clarity'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_security_group_create(
        region => 'Ascot',
        group_name => 'Acty',
        description => 'Ballade',
        vpc_id => 'Capa',
        tags => {openqa_var_job_id => 'CityJazz'});

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-security-group/ } @calls), 'Command create-security-group');
    ok((any { /tag-specifications/ } @calls), 'Tag specifications present');
    ok((any { /\{Key=openqa_var_job_id,Value=CityJazz\}/ } @calls), 'Tag passed to tag-specifications');
    ok(($res eq 'Clarity'), "Result is '$res' expected to be 'Clarity'");
};


subtest '[aws_security_group_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'Quint'; });

    my $res = aws_security_group_get_id(region => 'CR-X', job_id => 'CR-Z');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-security-groups/ } @calls), 'Command describe-security-groups');
    ok(($res eq 'Quint'), "Result is '$res' expected to be 'Quint'");
};

subtest '[aws_security_group_authorize_ingress]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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

subtest '[aws_tgw_vpc_attachment_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'AustinSevenRuby'; });

    my $res = aws_tgw_vpc_attachment_get_id(region => 'Rocky', job_id => '42');
    ok((any { /aws ec2 describe-transit-gateway-vpc-attachments/ } @calls), 'Command describe-transit-gateway-vpc-attachments');
    ok((any { /--filters 'Name=tag:Name,Values=42-tga'/ } @calls), 'Correct name tag filter');
    ok(($res eq 'AustinSevenRuby'), "Result is '$res' expected to be 'AustinSevenRuby'");
};

subtest '[aws_subnet_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'PrinceR380'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_subnet_create(
        region => 'Ascot',
        cidr => '10.0.1.0/24',
        vpc_id => 'Cherry/100A',
        tags => {openqa_var_job_id => '67890'}
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-subnet/ } @calls), 'Command create-subnet');
    ok((any { /tag-specifications/ } @calls), 'Tag specifications present');
    ok((any { /\{Key=openqa_var_job_id,Value=67890\}/ } @calls), 'Tag passed to tag-specifications');
    ok(($res eq 'PrinceR380'), "Result is '$res' expected to be 'PrinceR380'");
};

subtest '[aws_subnet_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_run => sub { push @calls, $_[0]; return 42; });
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return '["PrinceR380"]'; });

    my $ret = aws_subnet_delete(
        region => 'Beat',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-subnet/ } @calls), 'Command delete-subnets');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[aws_subnet_get_ids]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return '["Datsun240Z", "Datsun720"]'; });

    my @res = aws_subnet_get_ids(
        region => 'Ascot',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-subnets/ } @calls), 'Command describe-subnets');
    ok((any { /--output json/ } @calls), 'Output format is json');
    is_deeply(\@res, ['Datsun240Z', 'Datsun720'], 'Correct subnet IDs returned');
};

subtest '[aws_internet_gateway_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'magnite'; });
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = aws_internet_gateway_create(
        region => 'Ascot',
        tags => {openqa_var_job_id => '67890'}
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-internet-gateway/ } @calls), 'Command create-internet-gateway');
    ok((any { /tag-specifications/ } @calls), 'Tag specifications present');
    ok((any { /\{Key=openqa_var_job_id,Value=67890\}/ } @calls), 'Tag passed to tag-specifications');
    ok(($res eq 'magnite'), "Result is '$res' expected to be 'magnite'");
};

subtest '[aws_internet_gateway_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'magnite'; });

    my $res = aws_internet_gateway_get_id(
        region => 'Taft',
        job_id => '67890');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-internet-gateways/ } @calls), 'Command describe-internet-gateways');
    ok(($res eq 'magnite'), "Result is '$res' expected to be 'magnite'");
};

subtest '[aws_internet_gateway_attach]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    aws_internet_gateway_attach(
        vpc_id => 'vpc-12345',
        igw_id => 'magnite',
        region => 'Ascot'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 attach-internet-gateway/ } @calls), 'Command attach-internet-gateway');
};

subtest '[aws_internet_gateway_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'magnite'; });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return 'elgrand'; });

    my $res = aws_route_table_create(
        region => 'Beat',
        vpc_id => 'vpc-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 create-route-table/ } @calls), 'Command create-route-table');
    ok(($res eq 'elgrand'), "Result is '$res' expected to be 'elgrand'");
};

subtest '[aws_route_table_associate]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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
        tags => {openqa_var_job_id => 'Sylphy'}
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-images/ } @calls), 'Command describe-images');
    ok((any { /aws ec2 run-instances/ } @calls), 'Command run-instances');
    ok((any { /tag-specifications/ } @calls), 'Tag specifications present');
    ok((any { /\{Key=openqa_var_job_id,Value=Sylphy\}/ } @calls), 'Tag passed to tag-specifications');
    ok(($res eq 'i-123'), "Result is '$res' expected to be 'i-123'");
};

subtest '[aws_vm_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return '["i-123", "i-456"]'; });

    my @res = aws_vm_get_id(
        region => 'Almera',
        job_id => '67890'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok((any { /tag:OpenQAJobVm,Values=67890/ } @calls), 'Filter on job tag');
    ok((any { /instance-state-name,Values=pending,running,stopping,stopped/ } @calls), 'Filter on state');
    is_deeply(\@res, ['i-123', 'i-456'], 'All IDs returned');
};

subtest '[aws_vm_get_id] failure' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return ''; });

    my @res = aws_vm_get_id(region => 'Almera', job_id => '67890');
    is(scalar(@res), 0, 'Empty list on failure');
};

subtest '[aws_vm_get_id] malformed JSON' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return 'Daihatsu Charade'; });

    dies_ok { aws_vm_get_id(region => 'Almera', job_id => '67890') } 'Die on malformed JSON';
};

subtest '[aws_vm_get_id] null entries' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    $awscli->redefine(script_output => sub { return '["i-123", null]'; });
    my @res = aws_vm_get_id(region => 'Almera', job_id => '67890');
    is_deeply(\@res, ['i-123'], 'Undef entry filtered out');

    $awscli->redefine(script_output => sub { return '[null]'; });
    @res = aws_vm_get_id(region => 'Almera', job_id => '67890');
    is(scalar(@res), 0, 'All-null array returns empty list');

    $awscli->redefine(script_output => sub { return '[null, null]'; });
    @res = aws_vm_get_id(region => 'Almera', job_id => '67890');
    is(scalar(@res), 0, 'All-null array returns empty list');

    $awscli->redefine(script_output => sub { return 'null'; });
    @res = aws_vm_get_id(region => 'Almera', job_id => '67890');
    is(scalar(@res), 0, 'Top-level null returns empty list');

    $awscli->redefine(script_output => sub { return '{"id": "i-123"}'; });
    @res = aws_vm_get_id(region => 'Almera', job_id => '67890');
    is(scalar(@res), 0, 'Hash ref returns empty list');
};

subtest '[aws_vm_get_id] missing args' => sub {
    dies_ok { aws_vm_get_id(region => 'Almera') } 'Missing job_id';
    dies_ok { aws_vm_get_id(job_id => '67890') } 'Missing region';
};

subtest '[aws_vm_get_diagnostics]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return '{"id": "i-12345", "state": "running"}'; });

    my $res = aws_vm_get_diagnostics(region => 'us-west-2', instance_id => 'i-12345');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok((any { /--region us-west-2/ } @calls), 'Region in command');
    ok((any { /Name=instance-id,Values=i-12345/ } @calls), 'Instance id in filter');
    is($res->{state}, 'running', 'State in result');
};

subtest '[aws_vm_get_diagnostics] failure' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return 'null'; });

    ok(!defined(aws_vm_get_diagnostics(region => 'us-west-2', instance_id => 'i-12345')), 'undef on null');
};

subtest '[aws_vm_get_diagnostics] missing args' => sub {
    dies_ok { aws_vm_get_diagnostics(region => 'us-west-2') } 'Missing instance_id';
    dies_ok { aws_vm_get_diagnostics(instance_id => 'i-12345') } 'Missing region';
};

subtest '[aws_vm_describe_status]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    my %opts;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; %opts = @_[1 .. $#_]; return 'ok'; });

    my $res = aws_vm_describe_status(region => 'us-west-2', instance_id => 'i-12345');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /^timeout -k 5 60 aws / } @calls), 'aws is bounded by timeout');
    ok((any { /aws ec2 describe-instance-status/ } @calls), 'Command describe-instance-status');
    ok((any { /--region us-west-2/ } @calls), 'Region in command');
    ok((any { /--instance-ids i-12345/ } @calls), 'Instance id in command');
    ok((any { /--include-all-instances/ } @calls), 'Include not running instances');
    ok($opts{proceed_on_failure}, 'proceed_on_failure is set');
    ok(($res eq 'ok'), "Result is '$res' expected to be 'ok'");
};

subtest '[aws_vm_describe_status] missing args' => sub {
    dies_ok { aws_vm_describe_status(region => 'us-west-2') } 'Missing instance_id';
    dies_ok { aws_vm_describe_status(instance_id => 'i-12345') } 'Missing region';
};

subtest '[aws_vm_wait_status_ok]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    my @states = ('"pending"', '', '"running"');
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return shift @states; });

    my $ret = aws_vm_wait_status_ok(
        region => 'Almera',
        instance_id => 'i-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok((any { /--region Almera/ } @calls), 'Region in command');
    is(scalar(@calls), 3, 'Retry until running');
    is($ret, 0, 'Return 0 when running');
};

subtest '[aws_vm_wait_status_ok] timeout' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return '"pending"'; });
    dies_ok { aws_vm_wait_status_ok(region => 'Almera', instance_id => 'i-12345', timeout => 60, delay => 10) }
    qr/not running after 60 seconds, last state: 'pending'/;
};

subtest '[aws_vm_wait_status_ok] terminated' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return '"terminated"'; });

    dies_ok { aws_vm_wait_status_ok(region => 'Almera', instance_id => 'i-12345') }
    qr/not running after 600 seconds, last state: 'terminated'/;
};

subtest '[aws_vm_wait_status_ok] missing args' => sub {
    dies_ok { aws_vm_wait_status_ok(region => 'Almera') } 'Missing instance_id';
    dies_ok { aws_vm_wait_status_ok(instance_id => 'i-12345') } 'Missing region';
};

subtest '[aws_pubip_get]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_output => sub { push @calls, $_[0]; return '"1.2.3.4"'; });

    my $res = aws_pubip_get(
        region => 'Almera',
        instance_id => 'i-12345'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Command describe-instances');
    ok((any { /--region Almera/ } @calls), 'Region in command');
    ok((any { /Name=instance-id,Values=i-12345/ } @calls), 'Instance id in filter');
    is($res, '1.2.3.4', 'IP returned');
};

subtest '[aws_pubip_get] no IP' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return 'null'; });

    ok(!defined(aws_pubip_get(region => 'Almera', instance_id => 'i-12345')), 'undef on null');
};

subtest '[aws_pubip_get] missing args' => sub {
    dies_ok { aws_pubip_get(region => 'Almera') } 'Missing instance_id';
    dies_ok { aws_pubip_get(instance_id => 'i-12345') } 'Missing region';
};

subtest '[aws_vm_terminate]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
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

subtest '[aws_tgw_get_id]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(aws_filter_query => sub { return 'tgw-1'; });

    is(aws_tgw_get_id(mirror_tag => 'T', region => 'R'), 'tgw-1', 'Get TGW ID');
};

subtest '[aws_vpc_get_subnets]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return '[{"AZ":"a","SI":"s1"},{"AZ":"a","SI":"s2"},{"AZ":"b","SI":"s3"}]'; });

    my @res = aws_vpc_get_subnets(vpc_id => 'v');
    is(scalar @res, 2, 'Unique subnets per AZ');
    is($res[0], 's1', 'First subnet');
    is($res[1], 's3', 'Second subnet');
};

subtest '[aws_vpc_get_routing_tables]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(aws_filter_query => sub { return 'rtb-1'; });

    is(aws_vpc_get_routing_tables(vpc_id => 'v', region => 'r'), 'rtb-1', 'Get routing tables');
};

subtest '[aws_tgw_attachment_create]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $awscli->redefine(script_output => sub { return '{"TransitGatewayVpcAttachment":{"TransitGatewayAttachmentId":"at-1"}}'; });
    $awscli->redefine(aws_tgw_attachment_get => sub { return [{"State" => "available"}]; });

    my $res = aws_tgw_attachment_create(transit_gateway_id => 't', vpc_id => 'v', subnet_id_list => ['s'], name => 'n');
    ok($res, 'Creation success');
};

subtest '[aws_tgw_attachment_delete]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_run => sub { push @calls, $_[0]; });
    $awscli->redefine(aws_tgw_attachment_get => sub { return [{"State" => "deleted"}]; });

    my $res = aws_tgw_attachment_delete(id => 'at-1');
    ok((any { /delete-transit-gateway-vpc-attachment/ } @calls), 'Delete command');
    ok($res, 'Deletion success');
};

subtest '[aws_route_create_tgw]' => sub {
    my $awscli = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $awscli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $awscli->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    aws_route_create_tgw(rtable_id => 'r', target_ip_net => 'i', trans_gw_id => 't');
    ok((any { /create-route.*--transit-gateway-id t/ } @calls), 'Create route command');
};

done_testing;
