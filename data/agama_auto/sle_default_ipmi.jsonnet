{
  "product": {
    "id": "SLES_16.0"
  },
  "user": {
    "fullName": "Bernhard M. Wiedemann",
    "password": "$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/",
    "hashedPassword": true,
    "userName": "bernhard"
  },
  "root": {
    "password": "$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/",
    "hashedPassword": true
  },
  "scripts": {
    "pre": [
      {
        "name": "wipefs",
        "body": |||
          #!/usr/bin/env bash
          wipefs -fa /dev/sda
        |||
      }
    ],
    "post": [
      {
        "name": "enable root login",
        "chroot": true,
        "body": |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
        |||
      }
    ]
  }
}
