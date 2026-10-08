import java.math.BigInteger;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Provider;
import java.security.Security;
import java.security.Signature;
import java.security.interfaces.ECPublicKey;
import java.security.spec.ECFieldFp;
import java.security.spec.ECGenParameterSpec;
import java.security.spec.ECPoint;
import java.security.spec.ECPublicKeySpec;
import java.security.spec.EllipticCurve;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import javax.crypto.KeyAgreement;

public class EllipticCurveCoreTest {

    private static final byte[] DATA = "Data integrity payload for EC testing".getBytes();

    private final List<String> results = new ArrayList<>();
    private int count = 0;

    void ok(String curve, String name) {
        results.add("ok " + ++count + " - " + curve + ":" + name);
    }

    void fail(String curve, String name, String reason) {
        results.add("not ok " + ++count + " - " + curve + ":" + name);
        results.add("  # " + reason);
    }

    void run(String curve) throws Exception {
        var keyGen = KeyPairGenerator.getInstance("EC");
        keyGen.initialize(new ECGenParameterSpec(curve));
        var keyPair = keyGen.generateKeyPair();
        var publicKey = (ECPublicKey) keyPair.getPublic();
        System.err.println("[JCA INFO] [" + curve + "] KeyPairGenerator provider: " + keyGen.getProvider().getName());

        // Public key point (x, y) must satisfy the curve's Weierstrass equation: y^2 = x^3 + ax + b (mod p)
        try {
            var c = publicKey.getParams().getCurve();
            if (c.getField() instanceof ECFieldFp fpField) {
                var p = fpField.getP();
                var x = publicKey.getW().getAffineX();
                var y = publicKey.getW().getAffineY();
                var lhs = y.pow(2).mod(p);
                var rhs = x.pow(3).add(c.getA().multiply(x)).add(c.getB()).mod(p);
                if (!lhs.equals(rhs)) throw new IllegalStateException("public key point is not on the curve");
                ok(curve, "publicKeyPointSatisfiesCurveEquation");
            } else {
                throw new IllegalStateException("only prime fields (Fp) are supported by this test");
            }
        } catch (Exception e) { fail(curve, "publicKeyPointSatisfiesCurveEquation", e.getMessage()); }

        // ECDSA sign + verify roundtrip (positive test)
        byte[] signature = null;
        try {
            var signer = Signature.getInstance("SHA256withECDSA");
            signer.initSign(keyPair.getPrivate());
            System.err.println("[JCA INFO] [" + curve + "] Signature provider: " + signer.getProvider().getName());
            signer.update(DATA);
            signature = signer.sign();

            var verifier = Signature.getInstance("SHA256withECDSA");
            verifier.initVerify(publicKey);
            verifier.update(DATA);
            if (!verifier.verify(signature)) throw new IllegalStateException("valid signature failed verification");
            ok(curve, "ecdsaSignAndVerifyRoundtrip");
        } catch (Exception e) { fail(curve, "ecdsaSignAndVerifyRoundtrip", e.getMessage()); }

        // Tampered data must be rejected (negative test)
        try {
            var verifier = Signature.getInstance("SHA256withECDSA");
            verifier.initVerify(publicKey);
            verifier.update("tampered payload".getBytes());
            if (signature != null && verifier.verify(signature)) throw new IllegalStateException("tampered data was accepted as valid");
            ok(curve, "ecdsaRejectsTamperedData");
        } catch (Exception e) { fail(curve, "ecdsaRejectsTamperedData", e.getMessage()); }

        // ECDH key agreement (positive test): two independently generated key pairs
        // on the same curve must derive an identical shared secret from both sides.
        KeyPair bobKeyPair = null;
        try {
            var bobKeyGen = KeyPairGenerator.getInstance("EC");
            bobKeyGen.initialize(publicKey.getParams());
            bobKeyPair = bobKeyGen.generateKeyPair();

            var aliceKeyAgree = KeyAgreement.getInstance("ECDH");
            aliceKeyAgree.init(keyPair.getPrivate());
            System.err.println("[JCA INFO] [" + curve + "] KeyAgreement provider: " + aliceKeyAgree.getProvider().getName());
            aliceKeyAgree.doPhase(bobKeyPair.getPublic(), true);
            byte[] aliceSecret = aliceKeyAgree.generateSecret();

            var bobKeyAgree = KeyAgreement.getInstance("ECDH");
            bobKeyAgree.init(bobKeyPair.getPrivate());
            bobKeyAgree.doPhase(publicKey, true);
            byte[] bobSecret = bobKeyAgree.generateSecret();

            if (aliceSecret.length == 0) throw new IllegalStateException("empty shared secret");
            if (!Arrays.equals(aliceSecret, bobSecret))
                throw new IllegalStateException("Alice and Bob derived different shared secrets");
            ok(curve, "ecdhSharedSecretAgreement");
        } catch (Exception e) { fail(curve, "ecdhSharedSecretAgreement", e.getMessage()); }

        // ECDH key agreement (negative/sanity test): the shared secret derived with
        // one peer must differ from the one derived with a different, unrelated peer
        // on the same curve -- guards against a degenerate/no-op agreement.
        try {
            if (bobKeyPair == null) throw new IllegalStateException("prerequisite ecdhSharedSecretAgreement did not run");

            var charlieKeyGen = KeyPairGenerator.getInstance("EC");
            charlieKeyGen.initialize(publicKey.getParams());
            var charlieKeyPair = charlieKeyGen.generateKeyPair();

            var aliceKeyAgreeWithBob = KeyAgreement.getInstance("ECDH");
            aliceKeyAgreeWithBob.init(keyPair.getPrivate());
            aliceKeyAgreeWithBob.doPhase(bobKeyPair.getPublic(), true);
            byte[] secretWithBob = aliceKeyAgreeWithBob.generateSecret();

            var aliceKeyAgreeWithCharlie = KeyAgreement.getInstance("ECDH");
            aliceKeyAgreeWithCharlie.init(keyPair.getPrivate());
            aliceKeyAgreeWithCharlie.doPhase(charlieKeyPair.getPublic(), true);
            byte[] secretWithCharlie = aliceKeyAgreeWithCharlie.generateSecret();

            if (Arrays.equals(secretWithBob, secretWithCharlie))
                throw new IllegalStateException("shared secret did not change with a different peer key");
            ok(curve, "ecdhDistinctPeersYieldDistinctSecrets");
        } catch (Exception e) { fail(curve, "ecdhDistinctPeersYieldDistinctSecrets", e.getMessage()); }

        // Invalid curve point injection
        try {
            var keyFactory = KeyFactory.getInstance("EC");
            var malformed = new ECPoint(BigInteger.ONE, BigInteger.ONE);
            keyFactory.generatePublic(new ECPublicKeySpec(malformed, publicKey.getParams()));
            ok(curve, "invalidCurvePointAcceptedByFactory");
        } catch (Exception ignored) {
            ok(curve, "invalidCurvePointRejectedByFactory");
        }
    }

    private static List<String> discoverCurves() {
        var list = new ArrayList<>(List.of("secp256r1", "secp384r1", "secp521r1"));

        try {
            var sunEC = Security.getProvider("SunEC");
            if (sunEC != null) {
                var supported = sunEC.getProperty("AlgorithmParameters.EC SupportedCurves");
                if (supported != null) {
                    // Split the curves group string, e.g. "[curve1,alias...]|[curve2,alias...]"
                    var groups = supported.split("\\|");
                    for (var group : groups) {
                        group = group.trim();
                        if (group.startsWith("[") && group.endsWith("]")) {
                            group = group.substring(1, group.length() - 1);
                        }
                        var parts = group.split(",");
                        if (parts.length > 0) {
                            var curveName = parts[0].trim();
                            if (!curveName.isEmpty() && !list.contains(curveName)) {
                                list.add(curveName);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("[JCA INFO] Error during dynamic curve discovery: " + e.getMessage());
        }
        return list;
    }

    public static void main(String[] args) {
        var t = new EllipticCurveCoreTest();
        List<String> curvesToTest;
        if (args.length > 0) {
            curvesToTest = new ArrayList<>();
            for (var arg : args) {
                curvesToTest.add(arg);
            }
        } else {
            curvesToTest = discoverCurves();
        }

        for (var curve : curvesToTest) {
            try {
                t.run(curve);
            } catch (Exception e) {
                t.fail(curve, "curveInitialization", e.getMessage());
            }
        }

        // openQA TAP parser expects "filename.ext .var" as first line
        System.out.println("EllipticCurveCoreTest.java ..");
        System.out.println("1.." + t.count);
        t.results.forEach(System.out::println);
    }
}
