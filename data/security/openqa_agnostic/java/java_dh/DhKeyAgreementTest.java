import java.math.BigInteger;
import java.security.InvalidKeyException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.spec.InvalidKeySpecException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import javax.crypto.KeyAgreement;
import javax.crypto.interfaces.DHPublicKey;
import javax.crypto.spec.DHParameterSpec;
import javax.crypto.spec.DHPublicKeySpec;

public class DhKeyAgreementTest {

    // Key sizes (in bits) tested when no size is given on the command line
    private static final int[] DEFAULT_KEY_SIZES = {2048, 3072, 4096};

    private final List<String> results = new ArrayList<>();
    private int count = 0;

    void ok(String size, String name) {
        results.add("ok " + ++count + " - " + size + ":" + name);
    }

    void fail(String size, String name, String reason) {
        results.add("not ok " + ++count + " - " + size + ":" + name);
        results.add("  # " + reason);
    }

    private static byte[] agree(KeyPair own, java.security.PublicKey peer) throws Exception {
        var keyAgree = KeyAgreement.getInstance("DH");
        keyAgree.init(own.getPrivate());
        keyAgree.doPhase(peer, true);
        return keyAgree.generateSecret();
    }

    private static KeyPair generateKeyPair(DHParameterSpec params) throws Exception {
        var keyGen = KeyPairGenerator.getInstance("DH");
        keyGen.initialize(params);
        return keyGen.generateKeyPair();
    }

    void run(int bits) {
        var size = bits + "bit";

        // Alice generates a key pair of the requested size. All other checks need it.
        KeyPair aliceKeyPair;
        DHParameterSpec params;
        try {
            var keyGen = KeyPairGenerator.getInstance("DH");
            keyGen.initialize(bits);
            System.err.println("[JCA INFO] [" + size + "] KeyPairGenerator provider: " + keyGen.getProvider().getName());
            aliceKeyPair = keyGen.generateKeyPair();
            params = ((DHPublicKey) aliceKeyPair.getPublic()).getParams();
            if (params.getP().bitLength() != bits)
                throw new IllegalStateException("prime modulus has " + params.getP().bitLength() + " bits, expected " + bits);
            ok(size, "dhKeyPairGeneration");
        } catch (Exception e) {
            fail(size, "dhKeyPairGeneration", String.valueOf(e));
            return;
        }
        var alicePublic = (DHPublicKey) aliceKeyPair.getPublic();

        // DH key agreement (positive test): Bob re-uses the parameters (p, g) taken from
        // Alice's public key. Both sides must derive an identical, non-empty shared secret.
        KeyPair bobKeyPair = null;
        try {
            // In a real protocol Bob only receives Alice's public key, so he reads p and g from it
            bobKeyPair = generateKeyPair(alicePublic.getParams());

            var aliceKeyAgree = KeyAgreement.getInstance("DH");
            aliceKeyAgree.init(aliceKeyPair.getPrivate());
            System.err.println("[JCA INFO] [" + size + "] KeyAgreement provider: " + aliceKeyAgree.getProvider().getName());
            aliceKeyAgree.doPhase(bobKeyPair.getPublic(), true);
            byte[] aliceSecret = aliceKeyAgree.generateSecret();

            byte[] bobSecret = agree(bobKeyPair, alicePublic);

            if (aliceSecret.length == 0) throw new IllegalStateException("empty shared secret");
            if (!Arrays.equals(aliceSecret, bobSecret))
                throw new IllegalStateException("Alice and Bob derived different shared secrets");
            ok(size, "dhSharedSecretAgreement");
        } catch (Exception e) { fail(size, "dhSharedSecretAgreement", String.valueOf(e)); }

        // The shared secret is an integer smaller than p, so it can never be longer than p
        try {
            if (bobKeyPair == null) throw new IllegalStateException("prerequisite dhSharedSecretAgreement did not run");
            byte[] secret = agree(aliceKeyPair, bobKeyPair.getPublic());
            int maxLength = (bits + 7) / 8;
            if (secret.length > maxLength)
                throw new IllegalStateException("shared secret has " + secret.length + " bytes, maximum is " + maxLength);
            ok(size, "dhSharedSecretLengthWithinModulus");
        } catch (Exception e) { fail(size, "dhSharedSecretLengthWithinModulus", String.valueOf(e)); }

        // DH key agreement (negative/sanity test): the secret derived with one peer must
        // differ from the one derived with an unrelated peer on the same parameters --
        // guards against a degenerate/no-op agreement.
        try {
            if (bobKeyPair == null) throw new IllegalStateException("prerequisite dhSharedSecretAgreement did not run");
            var charlieKeyPair = generateKeyPair(params);
            byte[] secretWithBob = agree(aliceKeyPair, bobKeyPair.getPublic());
            byte[] secretWithCharlie = agree(aliceKeyPair, charlieKeyPair.getPublic());
            if (Arrays.equals(secretWithBob, secretWithCharlie))
                throw new IllegalStateException("shared secret did not change with a different peer key");
            ok(size, "dhDistinctPeersYieldDistinctSecrets");
        } catch (Exception e) { fail(size, "dhDistinctPeersYieldDistinctSecrets", String.valueOf(e)); }

        // Invalid public value injection (negative test): y = 1 forces the shared secret to 1
        // and so is a known attack on DH. The JCA must refuse it, either when the key is built
        // or when the key agreement uses it.
        try {
            var spec = new DHPublicKeySpec(BigInteger.ONE, params.getP(), params.getG());
            boolean rejected = false;
            try {
                var weakKey = KeyFactory.getInstance("DH").generatePublic(spec);
                agree(aliceKeyPair, weakKey);
            } catch (InvalidKeySpecException | InvalidKeyException expected) {
                rejected = true;
            }
            if (!rejected) throw new IllegalStateException("weak public value y=1 was accepted");
            ok(size, "dhRejectsInvalidPeerPublicValue");
        } catch (Exception e) { fail(size, "dhRejectsInvalidPeerPublicValue", String.valueOf(e)); }
    }

    public static void main(String[] args) {
        var t = new DhKeyAgreementTest();
        var sizes = new ArrayList<Integer>();

        // Optional arguments: one or more key sizes in bits
        for (var arg : args) {
            try {
                sizes.add(Integer.parseInt(arg));
            } catch (NumberFormatException e) {
                t.fail("args", "invalidKeySize", "'" + arg + "' is not a valid key size");
            }
        }
        if (args.length == 0) {
            for (int bits : DEFAULT_KEY_SIZES) sizes.add(bits);
        }

        for (int bits : sizes) {
            t.run(bits);
        }

        // openQA TAP parser expects "filename.ext .var" as first line
        System.out.println("DhKeyAgreementTest.java ..");
        System.out.println("1.." + t.count);
        t.results.forEach(System.out::println);
    }
}
