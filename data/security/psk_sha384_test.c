/*
 * psk_sha384_test.c - Test gnutls_psk_allocate_{client,server}_credentials2()
 *
 * Tests the credentials2 API that allows specifying the MAC algorithm
 * for TLS 1.3 PSK binders (GNUTLS_MAC_SHA256 / GNUTLS_MAC_SHA384).
 *
 * Uses the newer setter APIs throughout:
 *   - gnutls_psk_set_client_credentials2()  (datum-based username)
 *   - gnutls_psk_set_server_credentials_function3()  (returns flags)
 *
 * Positive tests:
 *   1. Both sides SHA256 (backward compat via credentials2)
 *   2. Both sides SHA384 (new feature)
 *
 * Negative tests:
 *   3. Server SHA384, client SHA256 -> binder mismatch, must fail
 *   4. Client SHA384, server SHA256 -> binder mismatch, must fail
 *   5. Wrong PSK key (SHA256) -> must fail
 *   6. Wrong PSK key (SHA384) -> must fail
 *   7. Unknown username -> must fail
 *
 * Output: TAP v13.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <gnutls/gnutls.h>

#define PSK_USERNAME  "testuser"
#define PSK_KEY_HEX   "DEADBEEFCAFEBABE0123456789ABCDEF"
#define WRONG_KEY_HEX "0000000000000000FFFFFFFFFFFFFFFF"
#define MAX_BUF       1024
#define TEST_MSG      "PSK-SHA384-TEST"

/* TLS 1.3, PSK-only key exchange, no certificates */
#define PRIO_TLS13_PSK \
"NORMAL:-VERS-ALL:+VERS-TLS1.3:-KX-ALL:+ECDHE-PSK:+DHE-PSK:+PSK"

static int verbose;

#define LOG(fmt, ...) do { \
if (verbose) fprintf(stderr, "  [DBG] " fmt "\n", ##__VA_ARGS__); \
} while (0)

/* ------------------------------------------------------------------ */
/* Server PSK callback (function3 style: returns key + flags)         */
/* ------------------------------------------------------------------ */
static int server_psk_func3(gnutls_session_t session,
                            const gnutls_datum_t *username,
                            gnutls_datum_t *key,
                            gnutls_psk_key_flags *flags)
{
  gnutls_datum_t hex_key;
  int ret;

  (void)session;

  LOG("server_psk_func3: username='%.*s' (%u bytes)",
      username->size, username->data, username->size);

  if (username->size != strlen(PSK_USERNAME) ||
    memcmp(username->data, PSK_USERNAME, username->size) != 0) {
    LOG("server_psk_func3: unknown user");
  return -1;
    }

    /* Decode hex -> raw and return as RAW key */
    hex_key.data = (unsigned char *)PSK_KEY_HEX;
    hex_key.size = strlen(PSK_KEY_HEX);

    ret = gnutls_hex_decode2(&hex_key, key);
    if (ret < 0)
      return -1;

  *flags = GNUTLS_PSK_KEY_RAW;
  return 0;
}

/* ------------------------------------------------------------------ */
/* Server thread                                                      */
/* ------------------------------------------------------------------ */
struct server_args {
  int fd;
  gnutls_mac_algorithm_t mac;
  int handshake_ret;   /* gnutls error from handshake (0 = ok) */
  int io_ret;          /* gnutls error from post-handshake I/O */
};

static void *server_thread(void *arg)
{
  struct server_args *sa = arg;
  gnutls_session_t session = NULL;
  gnutls_psk_server_credentials_t cred = NULL;
  int ret;
  char buf[MAX_BUF];

  sa->handshake_ret = -999;
  sa->io_ret = 0;

  ret = gnutls_init(&session, GNUTLS_SERVER | GNUTLS_NO_TICKETS);
  if (ret < 0) { sa->handshake_ret = ret; goto out; }

  ret = gnutls_priority_set_direct(session, PRIO_TLS13_PSK, NULL);
  if (ret < 0) { sa->handshake_ret = ret; goto out; }

  ret = gnutls_psk_allocate_server_credentials2(&cred, sa->mac);
  if (ret < 0) {
    LOG("server: allocate_server_credentials2: %s",
        gnutls_strerror(ret));
    sa->handshake_ret = ret;
    goto out;
  }

  gnutls_psk_set_server_credentials_function3(cred, server_psk_func3);

  ret = gnutls_credentials_set(session, GNUTLS_CRD_PSK, cred);
  if (ret < 0) { sa->handshake_ret = ret; goto out; }

  gnutls_transport_set_int(session, sa->fd);
  gnutls_handshake_set_timeout(session, 5000);

  do {
    ret = gnutls_handshake(session);
  } while (ret == GNUTLS_E_AGAIN || ret == GNUTLS_E_INTERRUPTED);

  sa->handshake_ret = ret;
  if (ret < 0) {
    LOG("server: handshake failed: %s", gnutls_strerror(ret));
    goto out;
  }

  LOG("server: handshake OK");

  /* Echo one message */
  do {
    ret = gnutls_record_recv(session, buf, sizeof(buf) - 1);
  } while (ret == GNUTLS_E_AGAIN || ret == GNUTLS_E_INTERRUPTED);

  if (ret > 0) {
    gnutls_record_send(session, buf, ret);
    sa->io_ret = 0;
  } else {
    sa->io_ret = ret;
  }

  gnutls_bye(session, GNUTLS_SHUT_WR);

  out:
  if (session)
    gnutls_deinit(session);
  if (cred)
    gnutls_psk_free_server_credentials(cred);
  close(sa->fd);
  return NULL;
}

/* ------------------------------------------------------------------ */
/* Client                                                             */
/* ------------------------------------------------------------------ */
struct client_result {
  int handshake_ret;
  int io_ret;
};

static struct client_result run_client(int fd, gnutls_mac_algorithm_t mac,
                                       const char *username,
                                       const char *key_hex)
{
  struct client_result cr = { .handshake_ret = -999, .io_ret = 0 };
  gnutls_session_t session = NULL;
  gnutls_psk_client_credentials_t cred = NULL;
  int ret;
  char buf[MAX_BUF];

  const gnutls_datum_t user_datum = {
    .data = (unsigned char *)username,
    .size = (unsigned int)strlen(username)
  };
  const gnutls_datum_t key_datum = {
    .data = (unsigned char *)key_hex,
    .size = (unsigned int)strlen(key_hex)
  };

  ret = gnutls_init(&session, GNUTLS_CLIENT);
  if (ret < 0) { cr.handshake_ret = ret; goto out; }

  ret = gnutls_priority_set_direct(session, PRIO_TLS13_PSK, NULL);
  if (ret < 0) { cr.handshake_ret = ret; goto out; }

  ret = gnutls_psk_allocate_client_credentials2(&cred, mac);
  if (ret < 0) {
    LOG("client: allocate_client_credentials2: %s",
        gnutls_strerror(ret));
    cr.handshake_ret = ret;
    goto out;
  }

  /* Datum-based setter (credentials2 companion) */
  ret = gnutls_psk_set_client_credentials2(cred, &user_datum,
                                           &key_datum,
                                           GNUTLS_PSK_KEY_HEX);
  if (ret < 0) { cr.handshake_ret = ret; goto out; }

  ret = gnutls_credentials_set(session, GNUTLS_CRD_PSK, cred);
  if (ret < 0) { cr.handshake_ret = ret; goto out; }

  gnutls_transport_set_int(session, fd);
  gnutls_handshake_set_timeout(session, 5000);

  do {
    ret = gnutls_handshake(session);
  } while (ret == GNUTLS_E_AGAIN || ret == GNUTLS_E_INTERRUPTED);

  cr.handshake_ret = ret;
  if (ret < 0) {
    LOG("client: handshake failed: %s", gnutls_strerror(ret));
    goto out;
  }

  LOG("client: handshake OK");

  /* Send test message and verify echo */
  ret = gnutls_record_send(session, TEST_MSG, strlen(TEST_MSG));
  if (ret < 0) { cr.io_ret = ret; goto cleanup; }

  do {
    ret = gnutls_record_recv(session, buf, sizeof(buf) - 1);
  } while (ret == GNUTLS_E_AGAIN || ret == GNUTLS_E_INTERRUPTED);

  if (ret > 0) {
    buf[ret] = '\0';
    if (strcmp(buf, TEST_MSG) == 0) {
      LOG("client: echo verified OK");
      cr.io_ret = 0;
    } else {
      LOG("client: echo mismatch!");
      cr.io_ret = -1;
    }
  } else {
    cr.io_ret = ret;
  }

  cleanup:
  gnutls_bye(session, GNUTLS_SHUT_WR);

  out:
  if (session)
    gnutls_deinit(session);
  if (cred)
    gnutls_psk_free_client_credentials(cred);
  close(fd);
  return cr;
}

/* ------------------------------------------------------------------ */
/* Test harness                                                       */
/* ------------------------------------------------------------------ */
static int make_socketpair(int fds[2])
{
  return socketpair(AF_UNIX, SOCK_STREAM, 0, fds);
}

struct test_case {
  const char *name;
  gnutls_mac_algorithm_t server_mac;
  gnutls_mac_algorithm_t client_mac;
  const char *username;
  const char *key_hex;
  int expect_success;
};

static int run_test(int test_num, const struct test_case *tc)
{
  int fds[2];
  pthread_t tid;
  struct server_args sa;
  struct client_result cr;

  if (make_socketpair(fds) < 0) {
    printf("not ok %d - %s\n", test_num, tc->name);
    printf("# socketpair: %s\n", strerror(errno));
    return 1;
  }

  sa.fd  = fds[0];
  sa.mac = tc->server_mac;

  if (pthread_create(&tid, NULL, server_thread, &sa) != 0) {
    printf("not ok %d - %s\n", test_num, tc->name);
    printf("# pthread_create: %s\n", strerror(errno));
    close(fds[0]);
    close(fds[1]);
    return 1;
  }

  cr = run_client(fds[1], tc->client_mac, tc->username, tc->key_hex);
  pthread_join(tid, NULL);

  int ok;
  if (tc->expect_success) {
    /* Both handshakes must succeed and I/O must work */
    ok = (cr.handshake_ret == 0 && sa.handshake_ret == 0 &&
    cr.io_ret == 0 && sa.io_ret == 0);
  } else {
    /* At least one handshake must have failed (not just I/O) */
    ok = (cr.handshake_ret < 0 || sa.handshake_ret < 0);
  }

  if (ok) {
    printf("ok %d - %s\n", test_num, tc->name);
  } else {
    printf("not ok %d - %s\n", test_num, tc->name);
    printf("# client handshake=%d (%s)\n", cr.handshake_ret,
           cr.handshake_ret < 0 ?
           gnutls_strerror(cr.handshake_ret) : "ok");
    printf("# client io=%d (%s)\n", cr.io_ret,
           cr.io_ret < 0 ? gnutls_strerror(cr.io_ret) : "ok");
    printf("# server handshake=%d (%s)\n", sa.handshake_ret,
           sa.handshake_ret < 0 ?
           gnutls_strerror(sa.handshake_ret) : "ok");
    printf("# server io=%d (%s)\n", sa.io_ret,
           sa.io_ret < 0 ? gnutls_strerror(sa.io_ret) : "ok");
    printf("# expected: %s\n",
           tc->expect_success ? "success" : "failure");
  }

  return ok ? 0 : 1;
}

/* ------------------------------------------------------------------ */
/* main                                                               */
/* ------------------------------------------------------------------ */
int main(int argc, char *argv[])
{
  int failures = 0;

  signal(SIGPIPE, SIG_IGN);

  if (argc > 1 && strcmp(argv[1], "-v") == 0)
    verbose = 1;

  gnutls_global_init();

  printf("TAP version 13\n");
  printf("# GnuTLS version: %s\n", gnutls_check_version(NULL));

  /* Runtime probe: check that credentials2 is functional.
   * This handles backports where version < 3.8.11 but the
   * API is present.  Note: compile-time availability is a
   * prerequisite — if headers lack the declarations, the
   * build fails before we get here. */
  {
    gnutls_psk_server_credentials_t probe;
    int rc = gnutls_psk_allocate_server_credentials2(
      &probe, GNUTLS_MAC_SHA256);
    if (rc == GNUTLS_E_INVALID_REQUEST) {
      printf("1..0 # SKIP credentials2 API not functional\n");
      gnutls_global_deinit();
      return 0;
    }
    if (rc >= 0)
      gnutls_psk_free_server_credentials(probe);
  }

  struct test_case tests[] = {
    /* --- Positive --- */
    {
      .name = "P1: both SHA256 (backward compat via credentials2)",
      .server_mac = GNUTLS_MAC_SHA256,
      .client_mac = GNUTLS_MAC_SHA256,
      .username   = PSK_USERNAME,
      .key_hex    = PSK_KEY_HEX,
      .expect_success = 1,
    },
    {
      .name = "P2: both SHA384 (new feature)",
      .server_mac = GNUTLS_MAC_SHA384,
      .client_mac = GNUTLS_MAC_SHA384,
      .username   = PSK_USERNAME,
      .key_hex    = PSK_KEY_HEX,
      .expect_success = 1,
    },

    /* --- Negative --- */
    {
      .name = "N1: server SHA384, client SHA256 (binder mismatch)",
      .server_mac = GNUTLS_MAC_SHA384,
      .client_mac = GNUTLS_MAC_SHA256,
      .username   = PSK_USERNAME,
      .key_hex    = PSK_KEY_HEX,
      .expect_success = 0,
    },
    {
      .name = "N2: client SHA384, server SHA256 (binder mismatch)",
      .server_mac = GNUTLS_MAC_SHA256,
      .client_mac = GNUTLS_MAC_SHA384,
      .username   = PSK_USERNAME,
      .key_hex    = PSK_KEY_HEX,
      .expect_success = 0,
    },
    {
      .name = "N3: wrong PSK key (both SHA256)",
      .server_mac = GNUTLS_MAC_SHA256,
      .client_mac = GNUTLS_MAC_SHA256,
      .username   = PSK_USERNAME,
      .key_hex    = WRONG_KEY_HEX,
      .expect_success = 0,
    },
    {
      .name = "N4: wrong PSK key (both SHA384)",
      .server_mac = GNUTLS_MAC_SHA384,
      .client_mac = GNUTLS_MAC_SHA384,
      .username   = PSK_USERNAME,
      .key_hex    = WRONG_KEY_HEX,
      .expect_success = 0,
    },
    {
      .name = "N5: unknown username (both SHA384)",
      .server_mac = GNUTLS_MAC_SHA384,
      .client_mac = GNUTLS_MAC_SHA384,
      .username   = "bogususer",
      .key_hex    = PSK_KEY_HEX,
      .expect_success = 0,
    },
  };

  int ntests = sizeof(tests) / sizeof(tests[0]);

  printf("1..%d\n", ntests);

  for (int i = 0; i < ntests; i++)
    failures += run_test(i + 1, &tests[i]);

  gnutls_global_deinit();

  return failures ? 1 : 0;
}
