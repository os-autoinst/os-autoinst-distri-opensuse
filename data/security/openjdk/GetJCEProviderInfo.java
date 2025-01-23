import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.Provider;
import java.security.Provider.Service;
import java.security.Security;

public class GetJCEProviderInfo
{
    private static String getProviderVersion(Provider p) {
        // Get Java version string (e.g. "1.8.0" or "11.0.2")
        String javaVersion = System.getProperty("java.version");
        
        // Parse major version:
        // For 1.8.0 -> extract 8
        // For 11.0.2 -> extract 11
        int majorVersion;
        if (javaVersion.startsWith("1.")) {
            majorVersion = Integer.parseInt(javaVersion.substring(2, 3));
        } else {
            majorVersion = Integer.parseInt(javaVersion.split("\\.")[0]);
        }
        
        // Use appropriate method based on version
        return majorVersion >= 9 ? p.getVersionStr() : String.valueOf(p.getVersion());
    }

    public static void main(String[] args) throws NoSuchAlgorithmException, NoSuchProviderException
    {
        System.out.printf("JCE Provider Info: %s %s/%s on %s %s%n", System.getProperty("java.vm.name"),
                          System.getProperty("java.runtime.version"),
                          System.getProperty("java.vm.version"),
                          System.getProperty("os.name"),
                          System.getProperty("os.version"));

        Provider[] providers;
        System.out.printf("Listing all JCA Security Providers.%n");
        providers = Security.getProviders();
        if (providers == null || providers.length == 0)
        {
            System.out.printf("No Results.%n");
            return;
        }
        for(Provider p : providers)
        {
            System.out.printf("--- Provider %s %s%n    info %s%n", p.getName(), getProviderVersion(p), p.getInfo());
            for(Service s : p.getServices())
            {
                System.out.printf(" + %s.%s : %s (%s)%n  tostring=%s%n", 
                    s.getType(), s.getAlgorithm(), s.getClassName(), s.getProvider().getName(), s.toString());
            }
        }
    }
}