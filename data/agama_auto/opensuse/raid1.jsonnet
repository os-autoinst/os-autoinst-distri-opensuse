{
  "bootloader": {
    "stopOnBootMenu": true
  },
  "product": {
    "id": "{{AGAMA_PRODUCT_ID}}"
  },
  "storage": {
    "drives": [
      {
        "partitions": [
          {
            "delete": true,
            "search": "*"
          },
          {
            "filesystem": {
              "path": "/boot",
              "type": "vfat"
            },
            "id": "esp",
            "size": "1024 MiB"
          },
          {
            "alias": "mdroot",
            "id": "raid",
            "size": "7.81 GiB"
          },
          {
            "alias": "mdswap",
            "id": "raid",
            "size": "512 MiB"
          }
        ]
      },
      {
        "partitions": [
          {
            "delete": true,
            "search": "*"
          },
          {
            "filesystem": {
              "type": "vfat"
            },
            "id": "esp",
            "size": "1024 MiB"
          },
          {
            "alias": "mdroot",
            "id": "raid",
            "size": "7.81 GiB"
          },
          {
            "alias": "mdswap",
            "id": "raid",
            "size": "512 MiB"
          }
        ],
        "search": "*"
      }
    ],
    "mdRaids": [
      {
        "devices": [
          "mdroot"
        ],
        "filesystem": {
          "path": "/",
          "type": {
            "btrfs": {
              "snapshots": false
            }
          }
        },
        "level": "raid1"
      },
      {
        "devices": [
          "mdswap"
        ],
        "filesystem": {
          "path": "swap"
        },
        "level": "raid0"
      }
    ]
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
  }
}
