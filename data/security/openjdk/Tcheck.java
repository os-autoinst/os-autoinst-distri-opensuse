// SPDX-License-Identifier: BSD-3-Clause

import javax.net.ssl.SSLContext;
import java.security.NoSuchAlgorithmException;
import java.security.Provider;
import java.security.Security;

public class Tcheck {

    public static void main(String[] args) {
        int i = 1;

		    System.out.println("Supported Security Providers:");
		    Provider [] providers = Security.getProviders();
		  
        for (Provider provider: providers) {
			      System.out.println(" " + i++ + ". " + provider.getInfo());
		    }
    }
}