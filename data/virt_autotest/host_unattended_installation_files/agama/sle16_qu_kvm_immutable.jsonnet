local svirt_profile = import 'sle16_x_qu_svirt.libsonnet';

function(product='SLES', mode='immutable', registration_code='')
  assert mode == 'immutable' : 'The SLE 16 QU KVM profile only supports immutable mode';
  local profile = svirt_profile(product=product, mode=mode, registration_code=registration_code);
  profile + {
    root: profile.root + {
      sshPublicKey: 'fake public key to enable sshd and open firewall',
    },
    software: {
      patterns: {
        add: [
          'kvm_server',
          'kvm_tools',
        ],
      },
      packages: [
        'curl',
        'wget',
        'acl',
        'openssh-server-config-rootlogin',
        'virt-bridge-setup',
      ],
    },
  }
