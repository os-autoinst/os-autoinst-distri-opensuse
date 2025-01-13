// from https://github.com/ecki/JavaCryptoTest/blob/main/src/main/java/net/eckenfels/test/jce/JCEProviderInfo.java
// package net.eckenfels.test.jce;

import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.Provider;
import java.security.Provider.Service;
import java.security.Security;

public class JCEProviderInfo
{
    public static void main(String[] args) throws NoSuchAlgorithmException, NoSuchProviderException
    {
        System.out.printf("JCE Provider Info: %s %s/%s on %s %s%n", System.getProperty("java.vm.name"),
                          System.getProperty("java.runtime.version"),
                          System.getProperty("java.vm.version"),
                          System.getProperty("os.name"),
                          System.getProperty("os.version"));

        Provider[] ps;
        if (args.length > 0)
        {
            System.out.printf("Searching for JCA Security Providers with filter=\"%s\"%n", args[0]);
            ps = Security.getProviders(args[0]);

        } else {
            System.out.printf("Listing all JCA Security Providers.%n");
            ps = (args.length>0)?Security.getProviders(args[0]):Security.getProviders();
        }
        if (ps == null || ps.length == 0)
        {
            System.out.printf("No Results.%n");
            return;
        }
        for(Provider p : ps)
        {
            System.out.printf("--- Provider %s %s%n    info %s%n", p.getName(), p.getVersion(), p.getInfo());
            for(Service s : p.getServices())
            {
                    System.out.printf(" + %s.%s : %s (%s)%n  tostring=%s%n", s.getType(), s.getAlgorithm(), s.getClassName(), s.getProvider().getName(), s.toString());
            }
        }
    }

}