# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>
# Author: Di Kong <di.kong@suse.com>
#
# This testsuite for the mitigations control on XEN PV guest.
# And we will integrate HVM control flow here soon.
#
# We are testing each parameter. To check the influence of each one of them.
#
# There is a data structure to store the data that for compare with the data in runtime system.
# When we found something of unexpection string, we call them go die.
# When we didn't find something of expection string, we call them go die too.
#
# mitigations_list = {
#	'<parameter name>' => {
#		<the value of parameter> => {
#			<secnario1> => {
#				#determine string.
#				determine => {'<cmd>' => ['']},
#				#expection string. If it doesn't appear go die
#				expected => {'<cmd>' => ['ecpection string1','expection string2']},
#				#unexpection string. If it appears go die.
#				unexpected => {'<cmd>' => ['unexpection string1']}
#			}
#			<secnario2> => {
#				.....
#			}
#		}
#	}
# }
#
#  _________________________________________________      ___________________________________________________
# |Start/check the parameters in the mitigation_list| => |Input the parameter=value into the cmdline settings|
#  -------------------------------------------------     |Then grub_config and reboot.                       |
#                                                         ---------------------------------------------------
#                                                                               /\
#                                                                               ||
#                                                                               ||
#                                                                               ||
#                                                                               ||
#  _________________________________________              ______________________\/_________________________
# |Recall the infos after success or failure|   <======  |check the outcomes based on the value's key value|
#  -----------------------------------------              -------------------------------------------------
#                 /\
#                 ||
#                 ||
#                 ||
#                 ||
#  _______________\/_________________
# |Remove the cmdline and grub_config.|
# |And pick the next para=value.      |_____________________________________________________
# |When pick the last key value in a dic, jump to the next para and repeat the process above.|
#  -----------------------------------------------------------------------------------------
#
#
# Put into pti, l1tf, mds into this structure. and The testing code will read them all and
# one by one execution checking.
#

package xen_domu_mitigation_test;
use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use Mitigation;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;
use bmwqemu;

our $DEBUG_MODE = get_var("XEN_DEBUG", 0);
our $DOMU_TYPE = get_required_var("DOMU_TYPE");
my $qa_password = get_var("QA_PASSWORD", "nots3cr3t");
my $install_media_url = get_required_var('INSTALL_MEDIA');

# Define domU related variables
my $extra_domu_kernel_param = get_required_var('EXTRA_KERNEL_PARAMETER_FOR_DOMU');

my $test_mode = get_required_var('TEST_MODE');
my $test_suite = get_required_var('TEST_SUITE');
my $hy_test_param = get_var('HYPER_TEST_PARAM', 'spec-ctrl=yes');
my $domu_name = get_var('DOMU_NAME');
if (!$domu_name) {
    $domu_name = "xen_" . "$DOMU_TYPE" . "_domu";
}

my $domu_imagepool_path = "/xen_" . "$DOMU_TYPE";
my $domu_ip_addr;

my $hyper_test_cases_hash = {
    'spec-ctrl' => {
        #This is hypervisor fully disable situation.
        no => {
            default => {
                nextmove => {}
            }
        },
        #This is hypervisor no-xen situation.
        "no-xen" => {
            default => {
                nextmove => {}
            }
        },
        #This is hypervisor default enable situation.
        yes => {
            default => {
                nextmove => {}
            }
        }
    }
};


my $pti_on_on_pv = {"pti=on" => {
        default => {
            expected => {'cat /proc/cmdline' => ['pti=on'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected,.*hypervisor mitigation required']},
            unexpected => {'cat /proc/cmdline' => ['pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation:.*PTI']}
        }
    }
};
my $pti_on_on_hvm = {"pti=on" => {
        default => {
            expected => {'cat /proc/cmdline' => ['pti=on'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI']},
            unexpected => {'cat /proc/cmdline' => ['pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected,.*hypervisor mitigation required']}
        }
    }
};

my $pti_off_on_pv = {"pti=off" => {
        default => {
            expected => {'cat /proc/cmdline' => ['pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected,.*hypervisor mitigation required']},
            unexpected => {'cat /proc/cmdline' => ['pti=on'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI']}
        }
    }
};
my $pti_off_on_hvm = {"pti=off" => {
        default => {
            expected => {'cat /proc/cmdline' => ['pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable']},
            unexpected => {'cat /proc/cmdline' => ['pti=on'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected,.*hypervisor mitigation required', 'Mitigation: PTI']}
        }
    }
};

my $pti_auto_on_pv = {"pti=auto" => {
        default => {
            expected => {'cat /proc/cmdline' => ['pti=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected,.*hypervisor mitigation required']},
            unexpected => {'cat /proc/cmdline' => ['pti=on', 'pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI', 'Vulnerable']}
        }
    }
};
my $pti_auto_on_hvm = {"pti=auto" => {
        default => {
            expected => {'cat /proc/cmdline' => ['pti=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI']},
            unexpected => {'cat /proc/cmdline' => ['pti=off', 'pti=off'], 'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected,.*hypervisor mitigation required']}
        }
    }
};

my $mds_full = {"mds=full" => {
        default => {
            expected => {'cat /proc/cmdline' => ['mds=full'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
            unexpected => {'cat /proc/cmdline' => ['mds=full,nosmt', 'mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown']}
        }
    }
};
my $mds_full_nosmt = {"mds=full,nosmt" => {
        default => {
            expected => {'cat /proc/cmdline' => ['mds=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
            unexpected => {'cat /proc/cmdline' => ['mds=full[^, ]', 'mds=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown']}
        }
    },
};

my $tsx_async_abort_full_on_haswell = {"tsx_async_abort=full" => {
        default => {
            expected => {'cat /proc/cmdline' => ['tsx_async_abort=full'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT disable']}
        }
    }
};
my $tsx_async_abort_full = {"tsx_async_abort=full" => {
        default => {
            expected => {'cat /proc/cmdline' => ['tsx_async_abort=full'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
            unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT disable']}
        }
    }
};
my $tsx_async_abort_full_nosmt_on_haswell = {"tsx_async_abort=full,nosmt" => {
        default => {
            expected => {'cat /proc/cmdline' => ['tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full[^, ]'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT vulnerable']}
        }
    },
};
my $tsx_async_abort_full_nosmt = {"tsx_async_abort=full,nosmt" => {
        default => {
            expected => {'cat /proc/cmdline' => ['tsx_async_abort=full,nosmt'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
            unexpected => {'cat /proc/cmdline' => ['tsx_async_abort=off', 'tsx_async_abort=full[^, ]'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable', 'Mitigation: Clear CPU buffers; SMT vulnerable']}
        }
    },
};
my $spectrev2_on = {"spectre_v2=on" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*RSB filling']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2=off', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable', '.*IBPB: disabled,.*STIBP: disabled']}
        }
    }
};
my $spectrev2_on_spec_ctrl_no = {"spectre_v2=on" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: disabled,.*RSB filling']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2=off', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional,.*IBRS_FW,.*RSB filling']}
        }
    }
};
my $spectrev2_off = {"spectre_v2=off" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2=off'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=auto', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*', 'IBPB: conditional,.*IBRS_FW,.*RSB filling']}
        }
    }
};
my $spectrev2_auto = {"spectre_v2=auto" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional,.*IBRS_FW,.*RSB filling']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*', 'Vulnerable,.*IBPB: disabled,.*STIBP: disabled']}
        }
    }
};
my $spectrev2_retpoline = {"spectre_v2=retpoline" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional,.*IBRS_FW,.*RSB filling']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced.*', 'Vulnerable,.*IBPB: disabled,.*STIBP: disabled']}
        }
    }
};
my $spectrev2_retpoline_spec_ctrl_no = {"spectre_v2=retpoline" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2=retpoline'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional,.*STIBP.*RSB filling']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2=on', 'spectre_v2=off', 'spectre_v2=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable,.*IBPB: disabled,.*STIBP: disabled']}
        }
    }
};
my $spectrev2_user_on = {"spectre_v2_user=on" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*RSB filling.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
        }
    }
};
my $spectrev2_user_on_spec_ctrl_no = {"spectre_v2_user=on" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=on'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: disabled']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
        }
    }
};
my $spectrev2_user_off = {"spectre_v2_user=off" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=off'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: disabled,.*RSB filling.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: conditional.*', 'IBPB: always-on.*']}
        }
    }
};
my $spectrev2_user_prctl = {"spectre_v2_user=prctl" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=prctl'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*']}
        }
    }
};
my $spectrev2_user_prctl_ibpb = {"spectre_v2_user=prctl,ibpb" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=prctl,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl[^, ]', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
        }
    }
};
my $spectrev2_user_seccomp = {"spectre_v2_user=seccomp" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=seccomp'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp,ibpb', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*']}
        }
    }
};
my $spectrev2_user_seccomp_ibpb = {"spectre_v2_user=seccomp,ibpb" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=seccomp,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp[^, ]', 'spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.* STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: conditional.*']}
        }
    }
};
my $spectrev2_user_auto = {"spectre_v2_user=auto" => {
        default => {
            expected => {'cat /proc/cmdline' => ['spectre_v2_user=auto'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: conditional.*']},
            unexpected => {'cat /proc/cmdline' => ['spectre_v2_user=on', 'spectre_v2_user=off', 'spectre_v2_user=prctl', 'spectre_v2_user=prctl,ibpb', 'spectre_v2_user=seccomp', 'spectre_v2_user=seccomp,ibpb'], 'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['IBPB: always-on,.*STIBP: forced,.*', 'IBPB: disabled,.*STIBP: disabled', 'IBPB: always-on.*']}
        }
    }
};

# tsx_async_abort is not affected on haswell
my $mitigations_auto_on_pv_haswell = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, STIBP: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_on_pv_icelake = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, STIBP: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_auto_on_pv_cascadelake = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS.*IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};


my $mitigations_auto_on_pv = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS.*IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Mitigation: Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_on_hvm = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS, IBPB: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_auto_on_hvm_haswell = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_auto_on_hvm_icelake = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_auto_on_hvm_cascadelake = {"mitigations=auto" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=auto'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS, IBPB: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};

my $mitigations_on_on_pv = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS.*IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_on_on_pv_haswell = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, STIBP: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_on_on_pv_icelake = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, STIBP: conditional, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_on_on_pv_cascadelake = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS.*IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};

my $mitigations_on_on_hvm = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS.*IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_on_on_hvm_haswell = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};
my $mitigations_on_on_hvm_icelake = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: Retpolines, IBPB: conditional, IBRS_FW, RSB filling'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Clear CPU buffers; SMT Host state unknown']},
            unexpected => {}
        }
    }
};

my $mitigations_on_on_hvm_cascadelake = {"mitigations=on" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=on'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Mitigation: IBRS.*IBPB: conditional, RSB filling.*'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Mitigation: PTI'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Clear CPU buffers; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Speculative Store Bypass disabled via prctl and seccomp'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};


# tsx_async_abort result is Not affected on haswell when mitigations=off
my $mitigations_off_on_pv_haswell = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable, IBPB: disabled, STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};

my $mitigations_off_on_pv = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable, IBPB: disabled, STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Unknown.*XEN PV detected, hypervisor mitigation required'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable']},
            unexpected => {}
        }
    }
};

my $mitigations_off_on_hvm = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable, IBPB: disabled, STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable']},
            unexpected => {}
        }
    }
};

my $mitigations_off_on_hvm_haswell = {"mitigations=off" => {
        default => {
            expected => {
                'cat /proc/cmdline' => ['mitigations=off'],
                'cat /sys/devices/system/cpu/vulnerabilities/spectre_v2' => ['Vulnerable, IBPB: disabled, STIBP: disabled'],
                'cat /sys/devices/system/cpu/vulnerabilities/meltdown' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'],
                'cat /sys/devices/system/cpu/vulnerabilities/spec_store_bypass' => ['Vulnerable'],
                'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};

my $corss_testcase_mds_taa_off = {"mds=off tsx_async_abort=off mmio_stale_data=off" => {
        default => {
            expected => {'cat /proc/cmdline' => ['mds=off tsx_async_abort=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Vulnerable']},
            unexpected => {}
        }
    }
};

my $corss_testcase_mds_taa_off_on_haswell = {"mds=off tsx_async_abort=off mmio_stale_data=off" => {
        default => {
            expected => {'cat /proc/cmdline' => ['mds=off tsx_async_abort=off'], 'cat /sys/devices/system/cpu/vulnerabilities/mds' => ['Vulnerable; SMT Host state unknown'], 'cat /sys/devices/system/cpu/vulnerabilities/tsx_async_abort' => ['Not affected']},
            unexpected => {}
        }
    }
};
# TODO DOMU_TYPE variable need to be define on web
my $pti = {};
my $mitigations = {};
my $tsx_async_abort = {};
my $cross_testcases = {};
my $mds = {%$mds_full, %$mds_full_nosmt};

if ($DOMU_TYPE =~ /pv/i) {
    $pti = {%$pti_on_on_pv, %$pti_off_on_pv, %$pti_auto_on_pv};
} elsif ($DOMU_TYPE =~ /hvm/i) {
    $pti = {%$pti_on_on_hvm, %$pti_off_on_hvm, %$pti_auto_on_hvm};
}

if ($bmwqemu::vars{MICRO_ARCHITECTURE} =~ /Haswell/i) {
    $tsx_async_abort = {%$tsx_async_abort_full_on_haswell, %$tsx_async_abort_full_nosmt_on_haswell};
    $cross_testcases = {%$corss_testcase_mds_taa_off_on_haswell};
    if ($DOMU_TYPE =~ /pv/i) {
        $mitigations = {%$mitigations_auto_on_pv_haswell, %$mitigations_on_on_pv_haswell, %$mitigations_off_on_pv_haswell};
    } else {
        $mitigations = {%$mitigations_auto_on_hvm_haswell, %$mitigations_on_on_hvm_haswell, %$mitigations_off_on_hvm_haswell};
    }
}
elsif ($bmwqemu::vars{MICRO_ARCHITECTURE} =~ /Cascadelake/i) {
    $tsx_async_abort = {%$tsx_async_abort_full_on_haswell, %$tsx_async_abort_full_nosmt_on_haswell};
    $cross_testcases = {%$corss_testcase_mds_taa_off_on_haswell};
    if ($DOMU_TYPE =~ /pv/i) {
        $mitigations = {%$mitigations_auto_on_pv_cascadelake, %$mitigations_on_on_pv_cascadelake, %$mitigations_off_on_pv_haswell};
    } else {
        $mitigations = {%$mitigations_auto_on_hvm_cascadelake, %$mitigations_on_on_hvm_cascadelake, %$mitigations_off_on_hvm_haswell};
    }
}
elsif ($bmwqemu::vars{MICRO_ARCHITECTURE} =~ /Icelake/i) {
    $tsx_async_abort = {%$tsx_async_abort_full, %$tsx_async_abort_full_nosmt};
    $cross_testcases = {%$corss_testcase_mds_taa_off};
    if ($DOMU_TYPE =~ /pv/i) {
        $mitigations = {%$mitigations_auto_on_pv_icelake, %$mitigations_on_on_pv_icelake, %$mitigations_off_on_pv};
    } else {
        $mitigations = {%$mitigations_auto_on_hvm_icelake, %$mitigations_on_on_hvm_icelake, %$mitigations_off_on_hvm};
    }
}

else {
    $tsx_async_abort = {%$tsx_async_abort_full, %$tsx_async_abort_full_nosmt};
    $cross_testcases = {%$corss_testcase_mds_taa_off};
    if ($DOMU_TYPE =~ /pv/i) {
        $mitigations = {%$mitigations_auto_on_pv, %$mitigations_on_on_pv, %$mitigations_off_on_pv};
    } else {
        $mitigations = {%$mitigations_auto_on_hvm, %$mitigations_on_on_hvm, %$mitigations_off_on_hvm};
    }
}



my $spectrev2 = {%$spectrev2_on, %$spectrev2_off, %$spectrev2_retpoline, %$spectrev2_user_on};
my $spectrev2_spec_ctrl_no = {%$spectrev2_on_spec_ctrl_no, %$spectrev2_off, %$spectrev2_retpoline_spec_ctrl_no, %$spectrev2_user_on};

my $spectrev2_user = {%$spectrev2_user_on, %$spectrev2_user_off, %$spectrev2_user_prctl, %$spectrev2_user_prctl_ibpb, %$spectrev2_user_seccomp, %$spectrev2_user_seccomp_ibpb, %$spectrev2_user_auto};
my $spectrev2_user_spec_ctrl_no = {%$spectrev2_user_on_spec_ctrl_no, %$spectrev2_user_off, %$spectrev2_user_prctl, %$spectrev2_user_prctl_ibpb, %$spectrev2_user_seccomp, %$spectrev2_user_seccomp_ibpb, %$spectrev2_user_auto};


my $domu_test_cases_hash_spec_ctrl_default = {pti => $pti,
    mds => $mds,
    tsx_async_abort => $tsx_async_abort,
    spectre_v2 => $spectrev2,
    spectre_v2_user => $spectrev2_user,
    mitigations => $mitigations,
    cross_cases => $cross_testcases
};
my $domu_test_cases_hash_spec_ctrl_no = {pti => $pti,
    mds => $mds,
    tsx_async_abort => $tsx_async_abort,
    spectre_v2 => $spectrev2_spec_ctrl_no,
    spectre_v2_user => $spectrev2_user_spec_ctrl_no,
    mitigations => $mitigations,
    cross_cases => $cross_testcases
};

sub install_domu {
    my $self = @_;
    my $domu_intall_param = '';
    script_run("virsh destroy \"${domu_name}\"");
    script_run("virsh  undefine --remove-all-storage \"${domu_name}\"");
    if (script_run("ls ${domu_imagepool_path} | grep ${domu_name}.disk") ne 0 or
        script_run("virsh list --all | grep \"${domu_name}\"") ne 0) {
        script_run("rm -rf ${domu_imagepool_path}");
        script_run("mkdir ${domu_imagepool_path}");
        script_run("qemu-img create -f qcow2 ${domu_imagepool_path}/${domu_name}.disk 20G");

        if ($DOMU_TYPE =~ /pv/i) {
            $domu_intall_param = " -p ";
        } else {
            $domu_intall_param = " -v ";
        }
        script_run("virt-install --name \"${domu_name}\" ${domu_intall_param} "
              . " --location \"${install_media_url}\""
              . " --extra-args ${extra_domu_kernel_param}"
              . " --disk path=${domu_imagepool_path}/${domu_name}.disk,size=20,format=qcow2"
              . " --network=bridge=br0"
              . " --memory=1024"
              . " --vcpu=2"
              . " --vnc"
              . " --events on_reboot=destroy"
              . " --serial pty", timeout => 5400);
    }
    # Check if the DomU is up
    script_run("virsh start \"${domu_name}\"");
}


sub get_domu_ip {
    return script_output("./get_guest_ip.sh \"${domu_name}\"", timeout => 1800);
}

sub exec_testcases {
    my $self = @_;

    install_domu();
    $domu_ip_addr = get_domu_ip();

    # Restore domU kernel parameters
    Mitigation::ssh_vm_cmd("cat /proc/cmdline | grep   \"mitigations=auto\"", $qa_password, $domu_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/s/mitigations=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $domu_ip_addr);
    Mitigation::config_and_reboot($qa_password, $domu_name, $domu_ip_addr);

    # Loop to execute test accounding to hash list
    my $domu_test_cases_hash = {};
    while (my ($hy_param, $hy_value_hash) = each %$hyper_test_cases_hash) {
        while (my ($hy_value, $hy_result_hash) = each %$hy_value_hash) {
            my $hy_prameter = $hy_param . '=' . $hy_value;
            if ($hy_value eq "yes" or $hy_value eq "no-xen") {
                $domu_test_cases_hash = $domu_test_cases_hash_spec_ctrl_default;
            } elsif ($hy_value eq "no") {
                $domu_test_cases_hash = $domu_test_cases_hash_spec_ctrl_no;
            }
            if ($hy_test_param and $hy_test_param ne $hy_prameter) {
                next;
            }

            if ($DEBUG_MODE) {
                #$test_mode = 'single';
                #$test_mode = 'all';
                #$test_suite = "mitigations";
                record_info("Debug",
                    "Hypervisor param: " . $hy_prameter . "\n"
                      . "Single TestSuite: " . $test_suite . "\n"
                      . "Single TestMode: " . $test_mode . "\n"
                      . "DomU Password: " . $qa_password . "\n"
                      . "DomU ip :" . $domu_ip_addr,
                    result => 'ok');
            } else {
                # Change hypervisor layer grub parameter
                bootloader_setup::add_grub_xen_cmdline_settings($hy_prameter, 1);
                Mitigation::reboot_and_wait($self, 150);
            }

            # Start vm and wait for up
            script_run("virsh start \"${domu_name}\"");
            record_info("Info", "Waiting for the vm up to go ahead ", result => 'ok');
            sleep 60;

            Mitigation::guest_cycle($self, $domu_test_cases_hash, $test_suite, $test_mode, $qa_password, $domu_name, $domu_ip_addr, $hy_prameter);

            # Restore hypervisor default parameters
            if (!$DEBUG_MODE) {
                bootloader_setup::remove_grub_xen_cmdline_settings($hy_prameter);
                bootloader_setup::grub_mkconfig();
            }
        }
    }

}

sub get_expect_script {
    my $self = @_;
    my $expect_script_name = 'get_guest_ip.sh';
    assert_script_run("curl -s -o ~/$expect_script_name " . data_url("mitigation/xen/$expect_script_name"));
    #assert_script_run("wget -N http://10.67.134.67/install/tools/get_guest_ip.sh");
    assert_script_run("chmod a+x " . $expect_script_name);
}
sub run {
    my $self = @_;
    select_console 'root-console';
    die "platform mistake, This system is not running as Dom0." if script_run("test -d /proc/xen");

    my $qa_repo_url = get_var("QA_REPO_RUL", "http://dist.suse.de/ibs/QA:/Head/SLE-15-SP2/");
    zypper_ar($qa_repo_url, name => 'qa-head');
    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'in -y xmlstarlet expect sshpass';

    get_expect_script();
    exec_testcases();
}

sub post_fail_hook {
    my ($self) = @_;
    my $hvm_domu_ip_addr = get_domu_ip();
    select_console 'root-console';
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/l1tf=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_domu_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/pti=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_domu_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/tsx_async_abort=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_domu_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/mds=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_domu_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/spectre_v2_user=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_domu_ip_addr);
    Mitigation::ssh_vm_cmd("sed -i '/GRUB_CMDLINE_LINUX=/s/spectre_v2=[a-z,]*/\\ /' /etc/default/grub", $qa_password, $hvm_domu_ip_addr);
    Mitigation::ssh_vm_cmd("grub2-mkconfig -o /boot/grub2/grub.cfg", $qa_password, $hvm_domu_ip_addr);
}
1;
