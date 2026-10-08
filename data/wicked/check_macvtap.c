// Small program to test macvtap interfaces
// the following command has been issued: arping -c 1 -I macvtap1 <destination
// IP> It then listens on /dev/tapX to check whether the correct answer was
// received.

#include <arpa/inet.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#define PACKET_SIZE 70
#define SOURCE_IP_POS_IN_ARRAY 38
#define DEST_IP_POS_IN_ARRAY 48
#define DEST_MAC1_POS_IN_ARRAY 10
#define DEST_MAC2_POS_IN_ARRAY 42
#define FILENAME_LENGTH 16
// Expected ARP packet
// -1 stands for unknown data
unsigned char
    arp_packet[PACKET_SIZE] =
        {0x00, 0x00, 0x00, 0x00, 0x00,
         0x00, 0x00, 0x00, 0x00, 0x00,       // 10 bytes preamble
         -2,   -2,   -2,   -2,   -2,   -2,   // destination MAC address (3rd input parameter)
         0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // source MAC address
         0x08, 0x06,                         // ARP protocol
         0x00, 0x01, 0x08, 0x00, 0x06, 0x04, // Ethernet <=> IP
         0x00, 0x02,                         // "is at" answer
         0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // source MAC address
         -2,   -2,   -2,   -2,               // source IP address (replaced with 1st input
                                             // param )
         -2,   -2,   -2,   -2,   -2,   -2,   // destination MAC address
         -2,   -2,   -2,   -2,               // destination IP address ( replaced with 2nd
                                             // input param)
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 18 bytes postamble
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

// macvtap file name
char fn[FILENAME_LENGTH];

// Read buffer
unsigned char buffer[PACKET_SIZE];

void read_macaddr() {
#define SYSFS_MAC "/sys/class/net/macvtap1/address"
  unsigned char *mac = (unsigned char*) &arp_packet[DEST_MAC1_POS_IN_ARRAY];

  FILE *fp = fopen(SYSFS_MAC, "r");
  if (fp == NULL){
    perror("Cannot open " SYSFS_MAC);
    exit(-1);
  }

  if (fscanf(fp, " %02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx",
              &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]) != 6){
    printf("[ERROR] Cannot read <source-mac> from " SYSFS_MAC);
    exit(-1);
  }
  memcpy(&arp_packet[DEST_MAC2_POS_IN_ARRAY], mac, 6);
}

// Search for /dev/tapX
void search_tap() {
  char *hint = "/sys/class/net/macvtap1/ifindex";
  FILE *fp = fopen(hint, "r");
  int index;

  if (fp == NULL) {
    printf("Can't open %s\n", hint);
    exit(-1);
  }
  fscanf(fp, "%d", &index);
  fclose(fp);

  snprintf(fn, 15, "/dev/tap%d", index);
  fn[15] = '\0';
  printf("Type device was found - %s \n", fn);
}

// Read 70 bytes from the tap device
void read_packet() {
  int fd;

  fd = open(fn, O_RDONLY);
  if (fd == -1) {
    printf("Can't open tap device %s\n", fn);
    exit(-2);
  }
  else {
    printf("Device %s opened. ready to read \n", fn);
  }
  if (read(fd, &buffer, PACKET_SIZE) < 0) {
    printf("Error reading %s\n", fn);
    close(fd);
    exit(-3);
  } else {
    printf("ARP packet catched \n");
  }
  close(fd);
}

void analyze_packet() {
  unsigned char *pbuffer;
  unsigned char *ppacket;
  int differ = 0;

  for (ppacket = arp_packet, pbuffer = buffer;
       ppacket < arp_packet + PACKET_SIZE; ppacket++, pbuffer++) {
    if (*ppacket != 255) {
      if (*pbuffer != *ppacket) {
        printf("arp[%u] buffer[%u] DIFFERS!\n", *ppacket, *pbuffer);
        differ = 1;
      } else {
        printf("arp[%u] buffer[%u] \n", *ppacket, *pbuffer);
      }
    }
  }
  if (differ == 1) {
    exit(-4);
  } else {
    printf("Success listening to tap device %s, received the expected ARP "
           "packet\n",
           fn);
  }
}

// Main program
int main(int argc, char **argv) {
  if (argc < 3) {
    printf("No input parameters. Exit \n");
    printf("Usage:\n  check_macvtap <source-ip> <dest-ip>\n");
    exit(-5);
  }
  // getting source and destination ips from command line and inserting them
  // into dedicated places in packet
  struct in_addr *source_ip =
      (struct in_addr *)&arp_packet[SOURCE_IP_POS_IN_ARRAY];
  if (inet_pton(AF_INET, argv[1], source_ip) != 1) {
    printf("[ERROR] Invalid <source-ip> given!\n");
    return -2;
  }

  struct in_addr *dest_ip = (struct in_addr *)&arp_packet[DEST_IP_POS_IN_ARRAY];
  if (inet_pton(AF_INET, argv[2], dest_ip) != 1){
    printf("[ERROR] Invalid <dest-ip> given\n");
    return -2;
  }

  search_tap();
  read_macaddr();
  read_packet();
  analyze_packet();

  return 0;
}
