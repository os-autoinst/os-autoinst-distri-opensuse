local repo = '{{INCIDENT_REPO}}';
local urls = if repo != '' then std.split(repo, ',') else [];
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
    addons: []
  },
  bootloader: {
    stopOnBootMenu: true,
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$0bUrc6YvA/qw$h1Z3pzadaxmc/KgcHRSEcYoU1ShVNymoXBaRAQZJ4ozVhTbCvdAMbGQrQAAX7cC9cLRybhsvDio3kBX/IB3xj/',
    hashedPassword: true,
    userName: 'bernhard'
  },
  root: {
    password: '$6$0bUrc6YvA/qw$h1Z3pzadaxmc/KgcHRSEcYoU1ShVNymoXBaRAQZJ4ozVhTbCvdAMbGQrQAAX7cC9cLRybhsvDio3kBX/IB3xj/',
    hashedPassword: true,
    sshPublicKey: '{{_SECRET_RSA_PUB_KEY}}'
  },
  software: {
    packages: [
      'xauth',
      'xmlstarlet',
      'virt-viewer'
    ],
    patterns: [
      'base',
      'kvm_server',
      'kvm_tools'
    ],
    extraRepositories:
      if std.length(urls) > 0 then
        [
          {
            alias: 'TEST_' + std.toString(i),
            url: urls[i],
            allowUnsigned: true
          }
          for i in std.range(0, std.length(urls) -1)
        ]
      else
        [],
    onlyRequired: false
  },
  questions: {
    policy: 'auto',
    answers: [
      {
        answer: 'Trust',
        class: 'software.import_gpg'
      }
    ]
  },
  scripts: {
    post: [
      {
        name: 'config_ssh',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          # Configure SSH for passwordless access to guests
          # Note: authorized_keys is already configured by Agama via root.sshPublicKey
          
          # 1. Setup SSH server (sshd) - configure server first
          systemctl enable sshd
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
          sshd_config_file="/etc/ssh/sshd_config.d/01-virt-test.conf"
          echo -e "TCPKeepAlive yes\nClientAliveInterval 60\nClientAliveCountMax 120" > $sshd_config_file
          
          # 2. Setup SSH client keys and config - configure client after server
          mkdir -p -m 700 /root/.ssh
          
          # Write private key (use 9A as newline placeholder, same as host_15.xml.ep)
          cat > /root/.ssh/id_rsa << 'EOF'
          {{_SECRET_RSA_PRIV_KEY}}
          EOF
          # Use perl for more reliable newline replacement (sed may have issues in some shells)
          perl -pi -e 's/9A/\n/g' /root/.ssh/id_rsa
          chmod 600 /root/.ssh/id_rsa
          
          # Write public key (for reference, Agama may have already created this)
          echo '{{_SECRET_RSA_PUB_KEY}}' > /root/.ssh/id_rsa.pub
          
          # Configure SSH client settings
          cat > /root/.ssh/config << 'EOF'
          StrictHostKeyChecking no
          HostKeyAlgorithms ssh-rsa,ssh-ed25519
          PreferredAuthentications publickey,password
          EOF
          chmod 600 /root/.ssh/config
        |||
      }
    ]
  }
}
