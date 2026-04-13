package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"os"
	"time"
)

func main() {
	cert, err := tls.LoadX509KeyPair("cert.pem", "key.pem")
	if err != nil {
		log.Fatalf("LoadX509KeyPair: %v", err)
	}

	ca, err := os.ReadFile("cert.pem")
	if err != nil {
		log.Fatalf("ReadFile: %v", err)
	}

	pool := x509.NewCertPool()
	pool.AppendCertsFromPEM(ca)

	serverConfig := &tls.Config{
		Certificates:     []tls.Certificate{cert},
		ClientCAs:        pool,
		MinVersion:       tls.VersionTLS13,
		CurvePreferences: []tls.CurveID{tls.X25519MLKEM768},
	}

	clientConfig := &tls.Config{
		RootCAs:            pool,
		ServerName:         "localhost",
		MinVersion:         tls.VersionTLS13,
		MaxVersion:         tls.VersionTLS13,
		InsecureSkipVerify: true,
		CurvePreferences:   []tls.CurveID{tls.X25519MLKEM768},
	}

	done := make(chan bool)

	go func() {
		listener, err := tls.Listen("tcp", "localhost:8443", serverConfig)
		if err != nil {
			log.Fatalf("Server Listen: %v", err)
		}
		defer listener.Close()

		conn, err := listener.Accept()
		if err != nil {
			log.Fatalf("Server Accept: %v", err)
		}
		defer conn.Close()

		buf := make([]byte, 1024)
		n, err := conn.Read(buf)
		if err != nil {
			log.Fatalf("Server Read: %v", err)
		}

		fmt.Printf("Server: received %q\n", string(buf[:n]))

		err = conn.(*tls.Conn).Handshake()
		if err != nil {
			log.Fatalf("Server Handshake: %v", err)
		}

		cs := conn.(*tls.Conn).ConnectionState()
		fmt.Printf("Server: TLS ver=0x%x, cipher=0x%x\n", cs.Version, cs.CipherSuite)
		done <- true
	}()

	time.Sleep(100 * time.Millisecond)

	go func() {
		conn, err := tls.Dial("tcp", "localhost:8443", clientConfig)
		if err != nil {
			log.Fatalf("Client Dial: %v", err)
		}
		defer conn.Close()

		_, err = conn.Write([]byte("Hello, post-quantum world!"))
		if err != nil {
			log.Fatalf("Client Write: %v", err)
		}

		err = conn.Handshake()
		if err != nil {
			log.Fatalf("Client Handshake: %v", err)
		}

		cs := conn.ConnectionState()
		fmt.Printf("Client: TLS ver=0x%x, cipher=0x%x\n", cs.Version, cs.CipherSuite)
		done <- true
	}()

	<-done
	<-done
}
