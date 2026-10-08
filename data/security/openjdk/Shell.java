// SPDX-License-Identifier: BSD-3-Clause

/* -*-mode:java; c-basic-offset:2; indent-tabs-mode:nil -*- */
/**
 * CLI JSch smoke test used by the openjdk FIPS suite.
 *
 *   $ javac -cp /usr/share/java/jsch.jar Shell.java
 *   $ java  -cp /usr/share/java/jsch.jar:. Shell user@host password
 *
 * Connects with JSch using the OpenJDK FIPS provider, runs `whoami`
 * over an exec channel, prints the output, and exits.
 */
import com.jcraft.jsch.*;

public class Shell {
  public static void main(String[] arg) {
    if (arg.length < 2 || arg[0].indexOf('@') < 0) {
      System.err.println("usage: Shell user@host password");
      System.exit(2);
    }

    String user = arg[0].substring(0, arg[0].indexOf('@'));
    String host = arg[0].substring(arg[0].indexOf('@') + 1);
    String passwd = arg[1];

    // SunPKCS11 EC private keys do not implement java.security.interfaces.ECPrivateKey,
    // so JSch's ECDH kex fails with ClassCastException in FIPS mode. Restrict kex to
    // RFC 3526 fixed groups (FIPS-approved across all SLE versions), strongest first,
    // and skip GEX because servers may return primes that newer NSS accepts but
    // SLE 15.x SunPKCS11-NSS-FIPS rejects with "Could not derive key".
    JSch.setConfig("kex",
        "diffie-hellman-group18-sha512," +
        "diffie-hellman-group16-sha512," +
        "diffie-hellman-group14-sha256");

    Session session = null;
    try {
      JSch jsch = new JSch();
      session = jsch.getSession(user, host, 22);
      session.setPassword(passwd);
      session.setConfig("StrictHostKeyChecking", "no");
      session.connect(30000);

      ChannelExec channel = (ChannelExec) session.openChannel("exec");
      channel.setCommand("whoami");
      channel.setInputStream(null);
      channel.setErrStream(System.err);
      java.io.InputStream in = channel.getInputStream();
      channel.connect(3000);

      byte[] buf = new byte[1024];
      while (true) {
        while (in.available() > 0) {
          int n = in.read(buf, 0, buf.length);
          if (n < 0) break;
          System.out.write(buf, 0, n);
        }
        if (channel.isClosed()) {
          if (in.available() > 0) continue;
          break;
        }
        try { Thread.sleep(100); } catch (Exception ignored) {}
      }
      System.out.flush();
      int rc = channel.getExitStatus();
      channel.disconnect();
      if (rc != 0) {
        System.err.println("remote command exited " + rc);
        System.exit(rc);
      }
    } catch (Exception e) {
      System.err.println(e);
      System.exit(1);
    } finally {
      if (session != null) session.disconnect();
    }
  }
}
