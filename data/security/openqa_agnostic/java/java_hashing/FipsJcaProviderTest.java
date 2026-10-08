import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.Security;
import java.util.ArrayList;
import java.util.List;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

public class FipsJcaProviderTest {

    private static final String FIPS_PROVIDER = "SunPKCS11-FIPS";
    private static final byte[] SAMPLE = "test".getBytes(StandardCharsets.UTF_8);

    private final List<String> results = new ArrayList<>();

    void ok(String name) {
        results.add("ok " + (results.size() + 1) + " - " + name);
    }

    void fail(String name, Exception e) {
        results.add("not ok " + (results.size() + 1) + " - " + name);
        results.add("  # " + e.getMessage().replace("\n", " "));
    }

    void run() throws Exception {
        String fipsEnabled = Files.readString(Path.of("/proc/sys/crypto/fips_enabled")).trim();
        if (!"1".equals(fipsEnabled)) {
            results.add("ok 1 - kernel FIPS mode not enabled # SKIP");
            return;
        }
        if (Security.getProvider(FIPS_PROVIDER) == null) {
            results.add("ok 1 - " + FIPS_PROVIDER + " provider not registered # SKIP");
            return;
        }

        // MD5 must be routed through the FIPS provider
        try {
            MessageDigest d = MessageDigest.getInstance("MD5");
            if (!FIPS_PROVIDER.equals(d.getProvider().getName()))
                throw new Exception("expected " + FIPS_PROVIDER + " got " + d.getProvider().getName());
            ok("md5RoutedThroughFipsProvider");
        } catch (Exception e) { fail("md5RoutedThroughFipsProvider", e); }

        // Every MessageDigest the FIPS provider exposes must hash via it
        Security.getProvider(FIPS_PROVIDER).getServices().stream()
                .filter(s -> s.getType().equals("MessageDigest"))
                .map(s -> s.getAlgorithm())
                .sorted()
                .forEach(algo -> {
                    try {
                        MessageDigest d = MessageDigest.getInstance(algo);
                        if (!FIPS_PROVIDER.equals(d.getProvider().getName()))
                            throw new Exception("wrong provider: " + d.getProvider().getName());
                        if (d.digest(SAMPLE).length == 0)
                            throw new Exception("empty digest");
                        ok("MessageDigest " + algo);
                    } catch (Exception e) { fail("MessageDigest " + algo, e); }
                });

        // Every Hmac* (non-PBE) the FIPS provider exposes must MAC via it
        Security.getProvider(FIPS_PROVIDER).getServices().stream()
                .filter(s -> s.getType().equals("Mac"))
                .map(s -> s.getAlgorithm())
                .filter(a -> a.startsWith("Hmac") && !a.startsWith("HmacPBE"))
                .sorted()
                .forEach(algo -> {
                    try {
                        Mac m = Mac.getInstance(algo);
                        m.init(new SecretKeySpec(new byte[m.getMacLength()], algo));
                        if (!FIPS_PROVIDER.equals(m.getProvider().getName()))
                            throw new Exception("wrong provider: " + m.getProvider().getName());
                        if (m.doFinal(SAMPLE).length == 0)
                            throw new Exception("empty MAC");
                        ok("Mac " + algo);
                    } catch (Exception e) { fail("Mac " + algo, e); }
                });
    }

    public static void main(String[] args) throws Exception {
        FipsJcaProviderTest t = new FipsJcaProviderTest();
        t.run();
        // openQA TAP parser expects "filename.ext .." as first line
        System.out.println("FipsJcaProviderTest.java ..");
        System.out.println("1.." + t.results.size());
        t.results.forEach(System.out::println);
    }
}
