import nacl.signing
import nacl.encoding
import sys

def test_pynacl():
    # Generate a new signing key
    signing_key = nacl.signing.SigningKey.generate()
    verify_key = signing_key.verify_key

    # Sign a message
    message = b"Hello, this is a test message."
    signed_message = signing_key.sign(message)

    # Verify the signed message
    try:
        verify_key.verify(signed_message)
        print("Message verified successfully.")
    except nacl.exceptions.BadSignatureError:
        print("Message verification failed.")
        sys.exit(1)  # Exit with an error code

def main():
    test_pynacl()

if __name__ == '__main__':
    main()
