use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use Data::Dumper;

use testapi 'set_var';
use qesapdeployment;
set_var('QESAP_CONFIG_FILE', 'MARLIN');

subtest '[qesap_aws_get_vpc_id]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @soft_failure;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'FISHERMAN'; });
    set_var('PUBLIC_CLOUD_REGION', 'OCEAN');

    qesap_aws_get_vpc_id(resource_group => 'LATTE');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # qesap_az_get_peering_name
    ok((any { /aws ec2 describe-instances/ } @calls), 'Base command aws ec2 describe-instances');
    ok((any { /--region OCEAN/ } @calls), 'Region from argument');
    ok((any { /--filters.*Values=LATTE/ } @calls), 'Filter resource_group in tag');
};

subtest '[qesap_aws_vnet_peering] died args' => sub {
    dies_ok { qesap_aws_vnet_peering(target_ip => 'OCEAN') } "Expected die for missing vpc_id";
    dies_ok { qesap_aws_vnet_peering(vpc_id => 'OCEAN') } "Expected die for missing target_ip";
};

subtest '[qesap_aws_get_region_subnets]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @outputs;
    my @result;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return pop @outputs if ($_[0] =~ /aws ec2 describe-subnets/); });
    push @outputs, '[
    {
        "AZ": "eu-central-1a",
        "SI": "subnet-00000000000000000"
    },
    {
        "AZ": "eu-central-1b",
        "SI": "subnet-11111111111111111"
    }]';

    @result = qesap_aws_get_region_subnets(vpc_id => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 describe-subnets --filters.*WHALE/ } @calls), 'Composition of describe-subnets command');
    ok((any { /subnet-00000000000000000/ } @result), 'Subnet subnet-00000000000000000 for eu-central-1a');
    ok((any { /subnet-11111111111111111/ } @result), 'Subnet subnet-11111111111111111 for eu-central-1b');

    # Filter for duplicated regions
    push @outputs, '[
    {
        "AZ": "eu-central-1a",
        "SI": "subnet-00000000000000000"
    },
    {
        "AZ": "eu-central-1a",
        "SI": "subnet-22222222222222222"
    },
    {
        "AZ": "eu-central-1b",
        "SI": "subnet-11111111111111111"
    }]';
    @result = qesap_aws_get_region_subnets(vpc_id => 'WHALE');
    ok((any { /subnet-00000000000000000/ } @result), 'Subnet subnet-00000000000000000 for eu-central-1a');
    ok((any { /subnet-11111111111111111/ } @result), 'Subnet subnet-11111111111111111 for eu-central-1b');
    ok((none { /subnet-22222222222222222/ } @result), 'Subnet subnet-22222222222222222 is duplicate for eu-central-1a');

    push @outputs, '[
    {
        "AZ": "eu-central-1a",
        "SI": "subnet-00000000000000000"
    },
    {
        "AZ": "eu-central-1b",
        "SI": "subnet-11111111111111111"
    },
    {
        "AZ": "eu-central-1b",
        "SI": "subnet-22222222222222222"
    },
    {
        "AZ": "eu-central-1a",
        "SI": "subnet-33333333333333333"
    }]';
    @result = qesap_aws_get_region_subnets(vpc_id => 'WHALE');
    ok((any { /subnet-00000000000000000/ } @result), 'Subnet subnet-00000000000000000 for eu-central-1a');
    ok((any { /subnet-11111111111111111/ } @result), 'Subnet subnet-11111111111111111 for eu-central-1b');
    ok((none { /subnet-22222222222222222/ } @result), 'Subnet subnet-22222222222222222 is duplicate for eu-central-1b');
    ok((none { /subnet-33333333333333333/ } @result), 'Subnet subnet-33333333333333333 is duplicate for eu-central-1a');
};

subtest '[qesap_aws_create_transit_gateway_vpc_attachment]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            my @tga_status = ({State => 'available'});
            return \@tga_status;
    });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return '{
    "TransitGatewayVpcAttachment": {
        "TransitGatewayAttachmentId": "tgw-attach-00000000000000000",
        "TransitGatewayId": "tgw-00000000000000000",
        "State": "pending",
        "Tags": [
            {
                "Key": "Name",
                "Value": "WHALE-tga"
            }
        ]
    }
}' if ($_[0] =~ /aws ec2 create-transit-gateway-vpc-attachment/);
    });
    my @subnets = ('subnet-00000000000000000', 'subnet-11111111111111111');

    my $res = qesap_aws_create_transit_gateway_vpc_attachment(
        transit_gateway_id => 'tgw-00000000000000000',
        vpc_id => 'vpc-00000000000000000',
        subnet_id_list => \@subnets,
        name => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res, 'Creation of transit gateway vpc attachment is fine.';
};

subtest '[qesap_aws_create_transit_gateway_vpc_attachment] timeout' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            my @tga_status = ({State => 'never_ready'});
            return \@tga_status;
    });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return '{
    "TransitGatewayVpcAttachment": {
        "TransitGatewayAttachmentId": "tgw-attach-00000000000000000",
        "TransitGatewayId": "tgw-00000000000000000",
        "State": "pending",
        "Tags": [
            {
                "Key": "Name",
                "Value": "WHALE-tga"
            }
        ]
    }
}' if ($_[0] =~ /aws ec2 create-transit-gateway-vpc-attachment/);
    });
    my @subnets = ('subnet-00000000000000000', 'subnet-11111111111111111');

    my $res = qesap_aws_create_transit_gateway_vpc_attachment(
        transit_gateway_id => 'tgw-00000000000000000',
        vpc_id => 'vpc-00000000000000000',
        subnet_id_list => \@subnets,
        name => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Creation of transit gateway vpc attachment timeout.';
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            push @calls, 'qesap_aws_get_transit_gateway_vpc_attachment';
            my @tga = ({TransitGatewayAttachmentId => '000000000000', State => 'deleted'});
            return \@tga;
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(name => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res, 'Delete of transit gateway vpc attachment is fine.';
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment] timeout' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            push @calls, 'qesap_aws_get_transit_gateway_vpc_attachment';
            my @tga = ({TransitGatewayAttachmentId => '000000000000', State => 'deleting'});
            return \@tga;
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(name => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Delete of transit gateway vpc attachment timeout.';
};

subtest '[qesap_aws_get_transit_gateway_vpc_attachment] no filters' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            #return a bare minimal valid json
            return '[]' if ($_[0] =~ /aws ec2 describe-transit-gateway-attachments/); });

    my $res = qesap_aws_get_transit_gateway_vpc_attachment(transit_gateway_attach_id => 'tgw-attach-00000000000000000');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  ##\$res##-->  " . Dumper($res));
    ok((any { /aws ec2 describe-transit-gateway-attachments/ } @calls), 'aws ec2 describe-transit-gateway-attachments is called');
};

subtest '[qesap_aws_get_transit_gateway_vpc_attachment] return multiple tga' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return '[
    { "TransitGatewayAttachmentId": "tgw-attach-00000000000000000" },
    { "TransitGatewayAttachmentId": "tgw-attach-11111111111111111" }
]' if ($_[0] =~ /aws ec2 describe-transit-gateway-attachments/); });

    my $res = qesap_aws_get_transit_gateway_vpc_attachment(transit_gateway_attach_id => 'tgw-attach-00000000000000000');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  ##\$res##-->  " . Dumper($res));
    ok($res->[0]->{TransitGatewayAttachmentId} eq 'tgw-attach-00000000000000000', 'Return the first TransitGatewayAttachmentId field of the json from script_output');
    ok($res->[1]->{TransitGatewayAttachmentId} eq 'tgw-attach-11111111111111111', 'Return the second TransitGatewayAttachmentId field of the json from script_output');
};

subtest '[qesap_aws_get_transit_gateway_vpc_attachment] transit_gateway_attach_id filter' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return '[
    {
        "TransitGatewayAttachmentId": "tgw-attach-00000000000000000",
        "State": "available",
        "CreationTime": "2023-06-15T11:06:44.000Z",
        "Tags": [
            {
                "Key": "Name",
                "Value": "WHALE-tga"
            }
        ]
    }
]' if ($_[0] =~ /aws ec2 describe-transit-gateway-attachments/); });

    my $res = qesap_aws_get_transit_gateway_vpc_attachment(transit_gateway_attach_id => 'tgw-attach-00000000000000000');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  ##\$res##-->  " . Dumper($res));
    ok($res->[0]->{TransitGatewayAttachmentId} eq 'tgw-attach-00000000000000000', 'Return the TransitGatewayAttachmentId field of the json from script_output');
    ok($res->[0]->{State} eq 'available', 'Return the State field of the json from script_output');
    ok((any { /--filter='Name=transit-gateway-attachment-id,Values=tgw-attach-00000000000000000'/ } @calls), 'Expected transit-gateway-attachment-id filter');
};

subtest '[qesap_aws_get_transit_gateway_vpc_attachment] name filter' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return '[
    {
        "TransitGatewayAttachmentId": "tgw-attach-00000000000000000",
        "State": "available",
        "CreationTime": "2023-06-15T11:06:44.000Z",
        "Tags": [
            {
                "Key": "Name",
                "Value": "WHALE-tga"
            }
        ]
    }
]' if ($_[0] =~ /aws ec2 describe-transit-gateway-attachments/); });

    my $res = qesap_aws_get_transit_gateway_vpc_attachment(name => 'WHALE*');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  ##\$res##-->  " . Dumper($res));
    ok($res->[0]->{TransitGatewayAttachmentId} eq 'tgw-attach-00000000000000000', 'Return the TransitGatewayAttachmentId field of the json from script_output');
    ok($res->[0]->{State} eq 'available', 'Return the State field of the json from script_output');
    ok((any { /aws ec2 describe-transit-gateway-attachments/ } @calls), 'aws ec2 describe-transit-gateway-attachments is called');
    ok((any { /--filter='Name=tag:Name,Values=WHALE\*'/ } @calls), 'Expected name filter');
};

subtest '[qesap_aws_add_route_to_tgw]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    qesap_aws_add_route_to_tgw(
        rtable_id => 'rtb-00000000000000000',
        target_ip_net => '10.0.0.1/28',
        trans_gw_id => 'tgw-00000000000000000');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 create-route/ } @calls), 'Composition of create-route command');
    ok((any { /--route-table-id.*rtb-00000000000000000/ } @calls), 'Composition of --route-table-id argument');
    ok((any { /--destination-cidr-block.*10\.0\.0\.1\/28/ } @calls), 'Composition of --destination-cidr-block argument');
    ok((any { /--transit-gateway-id.*tgw-00000000000000000/ } @calls), 'Composition of --transit-gateway-id argument');
};

subtest '[qesap_aws_get_mirror_tg]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'tgw-00deadbeef00'; });

    my $res = qesap_aws_get_mirror_tg();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 describe-transit-gateways/ } @calls), 'Composition of describe-transit-gateways command');
    ok($res eq 'tgw-00deadbeef00', 'Return the tgw id');
};

subtest '[qesap_aws_get_vpc_workspace]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'VPC_TAG_NAME'; });

    my $res = qesap_aws_get_vpc_workspace(vpc_id => 'PLANKTON');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 describe-vpcs.*PLANKTON/ } @calls), 'Composition of describe-vpcs command');
    ok($res eq 'VPC_TAG_NAME', 'Return the workspace name');
};

subtest '[qesap_aws_get_routing]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'rtb-00deadbeef00'; });

    my $res = qesap_aws_get_routing(vpc_id => 'PLANKTON');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 describe-route-tables.*PLANKTON/ } @calls), 'Composition of describe-route-tables command');
    ok($res eq 'rtb-00deadbeef00', 'Return the routing id');
};

subtest '[qesap_aws_vnet_peering]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_mirror_tg => sub { return 'tgw-00deadbeef00'; });
    $qesap->redefine(qesap_aws_get_region_subnets => sub { return ('subnet-00000000000000000', 'subnet-11111111111111111'); });
    $qesap->redefine(qesap_aws_create_transit_gateway_vpc_attachment => sub { return (1 == 1); });
    $qesap->redefine(qesap_aws_add_route_to_tgw => sub { push @calls, 'qesap_aws_add_route_to_tgw'; return; });
    $qesap->redefine(qesap_aws_get_routing => sub { return 'rtb-00deadbeef00'; });
    $qesap->redefine(qesap_aws_get_vpc_workspace => sub { return 'VPC_TAG_NAME'; });

    qesap_aws_vnet_peering(target_ip => '10.0.0.1/28', vpc_id => 'PLANKTON');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /qesap_aws_add_route_to_tgw/ } @calls), 'qesap_aws_add_route_to_tgw called');
};

subtest '[qesap_aws_vnet_peering] died when aws does not return expected output' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $tgw_return;
    $qesap->redefine(qesap_aws_get_mirror_tg => sub { return $tgw_return; });
    my $vpc_name;
    $qesap->redefine(qesap_aws_get_vpc_workspace => sub { return $vpc_name; });
    my @subnets;
    $qesap->redefine(qesap_aws_get_region_subnets => sub { return @subnets; });
    my $routing_id;
    $qesap->redefine(qesap_aws_get_routing => sub { return $routing_id; });
    $qesap->redefine(qesap_aws_create_transit_gateway_vpc_attachment => sub { return (1 == 1); });
    $qesap->redefine(qesap_aws_add_route_to_tgw => sub { push @calls, 'qesap_aws_add_route_to_tgw'; return; });

    my $res;
    $tgw_return = '';
    $res = qesap_aws_vnet_peering(target_ip => '10.0.0.1/28', vpc_id => 'PLANKTON');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Expected die for missing return from qesap_aws_vnet_peering.';

    $tgw_return = 'tgw-00deadbeef00';
    $vpc_name = '';
    $res = qesap_aws_vnet_peering(target_ip => '10.0.0.1/28', vpc_id => 'PLANKTON');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Expected die for missing return from qesap_aws_get_vpc_workspace.';

    $vpc_name = 'VPC_TAG_NAME';
    @subnets = ();
    $res = qesap_aws_vnet_peering(target_ip => '10.0.0.1/28', vpc_id => 'PLANKTON');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Expected die for missing return from qesap_aws_get_region_subnets.';

    @subnets = ('subnet-00000000000000000', 'subnet-11111111111111111');
    $routing_id = '';
    $res = qesap_aws_vnet_peering(target_ip => '10.0.0.1/28', vpc_id => 'PLANKTON');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Expected die for missing return from qesap_aws_get_routing.';
    $routing_id = 'rtb-00deadbeef00';
};

done_testing;
