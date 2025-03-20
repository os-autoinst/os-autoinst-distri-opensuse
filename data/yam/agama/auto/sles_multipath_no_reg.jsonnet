{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard',
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
  },
  scripts: {
    pre: [
      {
        name: 'activate multipath',
        body: |||
          #!/bin/bash
          if ! systemctl status multpathd ; then
            echo 'Activating multipath'
            systemctl start multipathd.socket
            systemctl start multipathd
          fi
        |||,
      },
    ],
  },
}
