// parsesign.go v0.0.1
// SPDX-License-Identifier: Apache-2.0
// this file comes from upstream https://github.com/autograph-pls/parsesign

package main

import (
	"encoding/asn1"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"
	"syscall"
)

// ASN.1 universal tag constants (complete set)
const (
	// Basic types
	TagBoolean          = 1
	TagInteger          = 2
	TagBitString        = 3
	TagOctetString      = 4
	TagNull             = 5
	TagObjectID         = 6
	TagObjectDescriptor = 7
	TagExternal         = 8
	TagReal             = 9
	TagEnumerated       = 10
	TagEmbeddedPDV      = 11
	TagUTF8String       = 12
	TagRelativeOID      = 13
	// 14-15 reserved
	TagSequence = 16
	TagSet      = 17

	// String types
	TagNumericString   = 18
	TagPrintable       = 19
	TagT61String       = 20 // TeletexString
	TagVideotexString  = 21
	TagIA5String       = 22
	TagUTCTime         = 23
	TagGeneralTime     = 24 // GeneralizedTime
	TagGraphicString   = 25
	TagVisibleString   = 26 // ISO646String
	TagGeneralString   = 27
	TagUniversalString = 28
	TagCharacterString = 29
	TagBMPString       = 30
)

// Maximum recursion depth limits to prevent infinite loops
const (
	MaxRecursionDepth   = 50
	MaxElementsPerLevel = 10000
	MaxTotalElements    = 100000
)

// Common certificate field OIDs
const (
	OIDCommonName       = "2.5.4.3"
	OIDCountryName      = "2.5.4.6"
	OIDLocalityName     = "2.5.4.7"
	OIDOrganizationName = "2.5.4.10"
	OIDEmailAddress     = "1.2.840.113549.1.9.1"
)

// Common OID mappings for display
var oidNames = map[string]string{
	// RSA signature algorithms
	"1.2.840.113549.1.1.1":  "rsaEncryption",
	"1.2.840.113549.1.1.2":  "md2WithRSAEncryption",
	"1.2.840.113549.1.1.4":  "md5WithRSAEncryption",
	"1.2.840.113549.1.1.5":  "sha1WithRSAEncryption",
	"1.2.840.113549.1.1.10": "rsaPSS",
	"1.2.840.113549.1.1.11": "sha256WithRSAEncryption",
	"1.2.840.113549.1.1.12": "sha384WithRSAEncryption",
	"1.2.840.113549.1.1.13": "sha512WithRSAEncryption",
	"1.2.840.113549.1.1.14": "sha224WithRSAEncryption",
	"1.2.840.113549.1.1.15": "sha512-224WithRSAEncryption",
	"1.2.840.113549.1.1.16": "sha512-256WithRSAEncryption",

	// ECDSA signature algorithms
	"1.2.840.10045.2.1":   "ecPublicKey",
	"1.2.840.10045.4.1":   "ecdsa-with-SHA1",
	"1.2.840.10045.4.3.1": "ecdsa-with-SHA224",
	"1.2.840.10045.4.3.2": "ecdsa-with-SHA256",
	"1.2.840.10045.4.3.3": "ecdsa-with-SHA384",
	"1.2.840.10045.4.3.4": "ecdsa-with-SHA512",

	// DSA signature algorithms
	"1.2.840.10040.4.1":      "dsaEncryption",
	"1.2.840.10040.4.3":      "dsa-with-sha1",
	"2.16.840.1.101.3.4.3.1": "dsa-with-sha224",
	"2.16.840.1.101.3.4.3.2": "dsa-with-sha256",

	// EdDSA algorithms
	"1.3.101.112": "Ed25519",
	"1.3.101.113": "Ed448",

	// GOST signature algorithms (Russian standards)
	"1.2.643.2.2.19":    "gost3410-2001",
	"1.2.643.7.1.1.1.1": "gost3410-2012-256",
	"1.2.643.7.1.1.1.2": "gost3410-2012-512",
	"1.2.643.2.2.3":     "gost3411-94-with-gost3410-2001",
	"1.2.643.7.1.1.3.2": "gost3411-2012-256-with-gost3410-2012-256",
	"1.2.643.7.1.1.3.3": "gost3411-2012-512-with-gost3410-2012-512",

	// Hash algorithms
	"1.2.840.113549.2.5":      "md5",
	"1.3.14.3.2.26":           "sha1",
	"2.16.840.1.101.3.4.2.1":  "sha256",
	"2.16.840.1.101.3.4.2.2":  "sha384",
	"2.16.840.1.101.3.4.2.3":  "sha512",
	"2.16.840.1.101.3.4.2.4":  "sha224",
	"2.16.840.1.101.3.4.2.5":  "sha512-224",
	"2.16.840.1.101.3.4.2.6":  "sha512-256",
	"2.16.840.1.101.3.4.2.7":  "sha3-224",
	"2.16.840.1.101.3.4.2.8":  "sha3-256",
	"2.16.840.1.101.3.4.2.9":  "sha3-384",
	"2.16.840.1.101.3.4.2.10": "sha3-512",
	"2.16.840.1.101.3.4.2.11": "shake128",
	"2.16.840.1.101.3.4.2.12": "shake256",

	// GOST hash algorithms
	"1.2.643.2.2.9":     "gost3411-94",
	"1.2.643.7.1.1.2.2": "gost3411-2012-256",
	"1.2.643.7.1.1.2.3": "gost3411-2012-512",

	// Elliptic curves
	"1.2.840.10045.3.1.1": "prime192v1",
	"1.2.840.10045.3.1.7": "prime256v1",
	"1.3.132.0.34":        "secp384r1",
	"1.3.132.0.35":        "secp521r1",
	"1.3.132.0.10":        "secp256k1",
	"1.2.840.10045.3.1.2": "prime192v2",
	"1.2.840.10045.3.1.3": "prime192v3",
	"1.2.840.10045.3.1.4": "prime239v1",
	"1.2.840.10045.3.1.5": "prime239v2",
	"1.2.840.10045.3.1.6": "prime239v3",

	// Post-quantum algorithms (NIST standardized)
	"2.16.840.1.101.3.4.3.17":  "ml-dsa-44",
	"2.16.840.1.101.3.4.3.18":  "ml-dsa-65",
	"2.16.840.1.101.3.4.3.19":  "ml-dsa-87",
	"1.3.6.1.4.1.2.267.12.4.4": "falcon-512",
	"1.3.6.1.4.1.2.267.12.6.5": "falcon-1024",
	"2.16.840.1.101.3.4.3.20":  "ml-kem-512",
	"2.16.840.1.101.3.4.3.21":  "ml-kem-768",
	"2.16.840.1.101.3.4.3.22":  "ml-kem-1024",

	// FIDO/WebAuthn algorithms
	"1.3.101.110": "X25519",
	"1.3.101.111": "X448",

	// Additional modern elliptic curves
	"1.3.36.3.3.2.8.1.1.7":  "brainpoolP256r1",
	"1.3.36.3.3.2.8.1.1.11": "brainpoolP384r1",
	"1.3.36.3.3.2.8.1.1.13": "brainpoolP512r1",

	// Microsoft specific OIDs
	"1.3.6.1.4.1.311.2.1.4":  "spcIndirectDataContent",
	"1.3.6.1.4.1.311.2.1.15": "spcPEImageData",
	"1.3.6.1.4.1.311.10.3.6": "spcEncryptedDigestRetryCount",
	"1.3.6.1.4.1.311.10.3.1": "microsoftCertTrustListSigning",
	"1.3.6.1.4.1.311.10.3.4": "microsoftEncryptedFileSystem",
	"1.3.6.1.4.1.311.20.2.2": "microsoftSmartcardLogon",
	"1.3.6.1.4.1.311.21.19":  "microsoftCertificateTemplate",
	"1.3.6.1.4.1.311.21.20":  "microsoftCertificateManager",

	// PKCS#7 / CMS content types
	"1.2.840.113549.1.7.1": "pkcs7-data",
	"1.2.840.113549.1.7.2": "pkcs7-signedData",
	"1.2.840.113549.1.7.3": "pkcs7-envelopedData",
	"1.2.840.113549.1.7.4": "pkcs7-signedAndEnvelopedData",
	"1.2.840.113549.1.7.5": "pkcs7-digestedData",
	"1.2.840.113549.1.7.6": "pkcs7-encryptedData",

	// PKCS#9 attributes
	"1.2.840.113549.1.9.2":  "unstructuredName",
	"1.2.840.113549.1.9.3":  "contentTypes",
	"1.2.840.113549.1.9.4":  "messageDigest",
	"1.2.840.113549.1.9.5":  "signingTime",
	"1.2.840.113549.1.9.6":  "countersignature",
	"1.2.840.113549.1.9.7":  "challengePassword",
	"1.2.840.113549.1.9.8":  "unstructuredAddress",
	"1.2.840.113549.1.9.9":  "extendedCertificateAttributes",
	"1.2.840.113549.1.9.14": "extensionReq",
	"1.2.840.113549.1.9.15": "sMIMECapabilities",
	"1.2.840.113549.1.9.16": "sMIMEObjectIdentifier",
	"1.2.840.113549.1.9.20": "friendlyName",
	"1.2.840.113549.1.9.21": "localKeyID",

	// Certificate extensions
	"2.5.29.14": "subjectKeyIdentifier",
	"2.5.29.15": "keyUsage",
	"2.5.29.17": "subjectAltName",
	"2.5.29.19": "basicConstraints",
	"2.5.29.32": "certificatePolicies",
	"2.5.29.35": "authorityKeyIdentifier",
	"2.5.29.37": "extKeyUsage",

	// Extended key usage
	"1.3.6.1.5.5.7.3.1": "serverAuth",
	"1.3.6.1.5.5.7.3.2": "clientAuth",
	"1.3.6.1.5.5.7.3.3": "codeSigning",
	"1.3.6.1.5.5.7.3.4": "emailProtection",
	"1.3.6.1.5.5.7.3.8": "timeStamping",

	// Distinguished name attributes
	OIDCommonName:       "commonName",
	OIDCountryName:      "countryName",
	OIDLocalityName:     "localityName",
	OIDOrganizationName: "organizationName",
	OIDEmailAddress:     "emailAddress",
	"2.5.4.4":           "surname",
	"2.5.4.5":           "serialNumber",
	"2.5.4.8":           "stateOrProvinceName",
	"2.5.4.9":           "streetAddress",
	"2.5.4.11":          "organizationalUnitName",
	"2.5.4.12":          "title",
	"2.5.4.42":          "givenName",
	"2.5.4.43":          "initials",
	"2.5.4.44":          "generationQualifier",
	"2.5.4.46":          "dnQualifier",
	"2.5.4.65":          "pseudonym",

	// Symmetric encryption algorithms
	"2.16.840.1.101.3.4.1.2":  "aes128-cbc",
	"2.16.840.1.101.3.4.1.6":  "aes128-gcm",
	"2.16.840.1.101.3.4.1.22": "aes192-cbc",
	"2.16.840.1.101.3.4.1.26": "aes192-gcm",
	"2.16.840.1.101.3.4.1.42": "aes256-cbc",
	"2.16.840.1.101.3.4.1.46": "aes256-gcm",
	"1.2.840.113549.3.2":      "rc2-cbc",
	"1.2.840.113549.3.4":      "rc4",

	// ChaCha20-Poly1305 and modern stream ciphers
	"1.2.840.113549.1.9.16.3.18": "chacha20-poly1305",

	// Certificate policy OIDs
	"2.23.140.1.2.1": "domain-validated",
	"2.23.140.1.2.2": "organization-validated",
	"2.23.140.1.2.3": "individual-validated",

	// FIDO Alliance OIDs
	"1.3.6.1.4.1.45724.1.1.4": "fido-u2f-transports",
	"1.3.6.1.4.1.45724.2.1.1": "fido-authenticator-aaguid",

	// GOST encryption algorithms
	"1.2.643.2.2.21":    "gost28147-89",
	"1.2.643.7.1.1.5.1": "gost3412-2015-magma",
	"1.2.643.7.1.1.5.2": "gost3412-2015-kuznyechik",

	// Chinese algorithms (SM series)
	"1.2.156.10197.1.301":   "sm2",
	"1.2.156.10197.1.401":   "sm3",
	"1.2.156.10197.1.104.1": "sm4-ecb",
	"1.2.156.10197.1.104.2": "sm4-cbc",

	// Japanese algorithms
	"1.2.392.200011.61.1.1.1.2": "camellia128-cbc",
	"1.2.392.200011.61.1.1.1.3": "camellia192-cbc",
	"1.2.392.200011.61.1.1.1.4": "camellia256-cbc",

	// Legacy algorithms
	"1.2.840.113549.3.7":     "des-ede3-cbc",
	"2.16.840.1.101.2.1.1.2": "fortezzaDSS",
	"1.2.840.113549.3.1":     "rc4-40",
}

const version = "0.0.1"

// Config holds command-line configuration
type Config struct {
	FilePath       string
	SaveFile       bool
	OutputFile     string
	ListAlgorithms bool
	ShowVersion    bool
}

// SignatureValidation holds validation results for signature fields
type SignatureValidation struct {
	HasCommonName       bool
	HasCountryName      bool
	HasLocalityName     bool
	HasOrganizationName bool
	HasEmailAddress     bool
	CommonName          string
	CountryName         string
	LocalityName        string
	OrganizationName    string
	EmailAddress        string
}

// IsValid returns true if all required certificate fields are present
func (sv SignatureValidation) IsValid() bool {
	return sv.HasCommonName && sv.HasCountryName && sv.HasLocalityName &&
		sv.HasOrganizationName && sv.HasEmailAddress
}

// ASN1Element represents a parsed ASN.1 element for display
type ASN1Element struct {
	Depth      int
	Offset     int
	HeaderLen  int
	Length     int
	Tag        int
	Class      int
	IsCompound bool
	TagName    string
	Content    string
}

// SignatureParser handles parsing and validation of ASN.1 signatures
type SignatureParser struct {
	data []byte
}

// NewSignatureParser creates a new signature parser
func NewSignatureParser(data []byte) *SignatureParser {
	return &SignatureParser{data: data}
}

// FindValidSignature searches backwards for valid signature with 0x30 0x82 marker
func (sp *SignatureParser) FindValidSignature() (*asn1.RawValue, int, error) {
	// Safety check for minimum data size
	if len(sp.data) < 2 {
		return nil, 0, errors.New("insufficient data for signature search")
	}

	// Search backwards for 0x30 0x82 pattern
	for i := len(sp.data) - 2; i >= 0; i-- {
		if sp.data[i] == 0x30 && sp.data[i+1] == 0x82 {
			// Safety check before creating buffer slice
			if i >= len(sp.data) {
				continue
			}

			// Try to parse ASN.1 structure from this position
			buffer := sp.data[i:]
			var raw asn1.RawValue
			_, err := asn1.Unmarshal(buffer, &raw)
			if err != nil {
				continue // Invalid structure, continue searching
			}

			// Additional safety check for raw.FullBytes
			if raw.FullBytes == nil || len(raw.FullBytes) == 0 {
				continue
			}

			// Validate signature fields
			validation := sp.validateSignatureFields(raw.FullBytes)
			if !validation.IsValid() {
				continue // Missing required fields, continue searching
			}

			return &raw, i, nil
		}
	}

	return nil, 0, errors.New("no valid signature found")
}

// validateSignatureFields checks for required certificate fields in ASN.1 data
func (sp *SignatureParser) validateSignatureFields(data []byte) SignatureValidation {
	validation := SignatureValidation{}
	sp.findFieldsInASN1(data, &validation)
	return validation
}

// findFieldsInASN1 recursively searches for certificate fields
func (sp *SignatureParser) findFieldsInASN1(data []byte, validation *SignatureValidation) {
	sp.findFieldsInASN1WithDepth(data, validation, 0)
}

// findFieldsInASN1WithDepth recursively searches for certificate fields with depth tracking
func (sp *SignatureParser) findFieldsInASN1WithDepth(data []byte, validation *SignatureValidation, depth int) {
	// Prevent infinite recursion
	if depth > MaxRecursionDepth {
		return
	}
	// Safety check for nil or empty data
	if data == nil || len(data) == 0 {
		return
	}

	offset := 0
	elementCount := 0

	for offset < len(data) && elementCount < MaxElementsPerLevel {
		element, bytesRead, err := parseASN1Element(data[offset:], 0, offset)
		if err != nil {
			break
		}

		// Check if this is an OID we're looking for
		if element.Tag == TagObjectID && element.Length > 0 {
			// Bounds check for OID content slice
			start := offset + element.HeaderLen
			end := start + element.Length
			if start < 0 || end < 0 || start >= len(data) || end > len(data) || start > end {
				break
			}
			content := data[start:end]
			oid := parseOID(content)

			// Look for the value immediately following this OID
			valueOffset := offset + bytesRead
			if valueOffset < len(data) {
				valueElement, _, err := parseASN1Element(data[valueOffset:], 0, valueOffset)
				if err == nil && !valueElement.IsCompound && valueElement.Length > 0 {
					// Bounds check for value content slice
					valueStart := valueOffset + valueElement.HeaderLen
					valueEnd := valueStart + valueElement.Length
					if valueStart < 0 || valueEnd < 0 || valueStart >= len(data) || valueEnd > len(data) || valueStart > valueEnd {
						continue
					}
					valueBytes := data[valueStart:valueEnd]
					valueContent := string(valueBytes)

					sp.setValidationField(validation, oid, valueContent)
				}
			}
		}

		// Recursively search in compound elements
		if element.IsCompound && element.Length > 0 {
			contentStart := element.HeaderLen
			if contentStart < bytesRead && element.Length <= len(data[offset:])-contentStart {
				// Additional bounds check for recursive content slice
				recursiveStart := offset + contentStart
				recursiveEnd := recursiveStart + element.Length
				if recursiveStart < 0 || recursiveEnd < 0 || recursiveStart >= len(data) || recursiveEnd > len(data) || recursiveStart > recursiveEnd {
					continue
				}
				content := data[recursiveStart:recursiveEnd]
				sp.findFieldsInASN1WithDepth(content, validation, depth+1)
			}
		}

		offset += bytesRead
		elementCount++
	}
}

// setValidationField sets the appropriate validation field based on OID
func (sp *SignatureParser) setValidationField(validation *SignatureValidation, oid, value string) {
	switch oid {
	case OIDCommonName:
		validation.HasCommonName = true
		validation.CommonName = value
	case OIDCountryName:
		validation.HasCountryName = true
		validation.CountryName = value
	case OIDLocalityName:
		validation.HasLocalityName = true
		validation.LocalityName = value
	case OIDOrganizationName:
		validation.HasOrganizationName = true
		validation.OrganizationName = value
	case OIDEmailAddress:
		validation.HasEmailAddress = true
		validation.EmailAddress = value
	}
}

// recursively finds the last OCTET STRING element
// calculateKeySize recursively finds the last OCTET STRING element
// when found, returns the keySize
func (sp *SignatureParser) calculateKeySize(data []byte, depth int) int {
	// Prevent infinite recursion
	if depth > MaxRecursionDepth {
		return 0
	}

	// Safety check for nil or empty data
	if data == nil || len(data) == 0 {
		return 0
	}

	offset := 0
	var keySize int
	var lastElement ASN1Element
	elementCount := 0

	for offset < len(data) && elementCount < MaxElementsPerLevel {
		element, bytesRead, err := parseASN1Element(data[offset:], depth, offset)
		if err != nil {
			break
		}

		lastElement = element

		if element.IsCompound && element.Length > 0 {
			contentStart := element.HeaderLen
			if contentStart < bytesRead && element.Length <= len(data[offset:])-contentStart {
				// Bounds check for keySize calculation
				keyStart := offset + contentStart
				keyEnd := keyStart + element.Length
				if keyStart >= 0 && keyEnd >= 0 && keyStart < len(data) && keyEnd <= len(data) && keyStart <= keyEnd {
					content := data[keyStart:keyEnd]
					keySize = sp.calculateKeySize(content, depth+1)
				}
			}
		}

		offset += bytesRead
		elementCount++
	}

	// Check if the last element is an OCTET STRING and calculate key size
	if lastElement.Tag == TagOctetString {
		keySize = lastElement.Length * 8
	}
	return keySize
}

// DisplayResults shows the signature analysis results
type DisplayResults struct {
	Validation SignatureValidation
	KeySize    int
	Offset     int
	Size       int
}

// Print displays the validation results
func (dr DisplayResults) Print() {
	fmt.Println("========================================")
	fmt.Println("Signature Validation:")
	dr.printField("Common Name", dr.Validation.HasCommonName, dr.Validation.CommonName)
	dr.printField("Country Name", dr.Validation.HasCountryName, dr.Validation.CountryName)
	dr.printField("Locality Name", dr.Validation.HasLocalityName, dr.Validation.LocalityName)
	dr.printField("Organization Name", dr.Validation.HasOrganizationName, dr.Validation.OrganizationName)
	dr.printField("Email Address", dr.Validation.HasEmailAddress, dr.Validation.EmailAddress)

	if dr.Validation.IsValid() {
		fmt.Println("✓ Valid signature - all required fields present")
	} else {
		fmt.Println("✗ Invalid signature - missing required fields")
	}
}

// printField prints a validation field with its value
func (dr DisplayResults) printField(name string, hasField bool, value string) {
	fmt.Printf("  %s: %v", name, hasField)
	if hasField && value != "" {
		fmt.Printf(" (%s)", value)
	}
	fmt.Println()
}

// ASN1Displayer handles ASN.1 structure display
type ASN1Displayer struct{}

// Display parses and displays ASN.1 structure
func (ad ASN1Displayer) Display(data []byte, baseOffset int) error {
	return ad.parseAndDisplayASN1(data, 0, baseOffset)
}

// parseAndDisplayASN1 recursively parses and displays ASN.1 structure
func (ad ASN1Displayer) parseAndDisplayASN1(data []byte, depth int, baseOffset int) error {
	// Prevent infinite recursion
	if depth > MaxRecursionDepth {
		fmt.Printf("%s[MAX DEPTH REACHED]: Recursion limit exceeded\n", strings.Repeat("  ", depth))
		return errors.New("maximum recursion depth exceeded")
	}

	// Safety check for nil or empty data
	if data == nil || len(data) == 0 {
		return nil
	}

	offset := 0
	elementCount := 0

	for offset < len(data) && elementCount < MaxElementsPerLevel {
		element, bytesRead, err := parseASN1Element(data[offset:], depth, baseOffset+offset)
		if err != nil {
			return err
		}

		ad.displayElement(element)

		if element.IsCompound && element.Length > 0 {
			contentStart := element.HeaderLen
			if contentStart < bytesRead && element.Length <= len(data[offset:])-contentStart {
				// Bounds check for display content slice
				displayStart := offset + contentStart
				displayEnd := displayStart + element.Length
				if displayStart >= 0 && displayEnd >= 0 && displayStart < len(data) && displayEnd <= len(data) && displayStart <= displayEnd {
					content := data[displayStart:displayEnd]
					if err := ad.parseAndDisplayASN1(content, depth+1, baseOffset+offset+contentStart); err != nil {
						// If parsing nested content fails, show as hex dump
						fmt.Printf("%s[HEX DUMP]: %s\n", strings.Repeat("  ", depth+1),
							hex.EncodeToString(content))
					}
				}
			}
		}

		offset += bytesRead
		elementCount++

		// Additional safety check to prevent runaway parsing
		if elementCount >= MaxElementsPerLevel {
			fmt.Printf("%s[TRUNCATED]: Too many elements at this level\n", strings.Repeat("  ", depth))
			break
		}
	}

	return nil
}

// displayElement displays a single ASN.1 element
func (ad ASN1Displayer) displayElement(element ASN1Element) {
	lengthStr := fmt.Sprintf("l=%d", element.Length)
	headerStr := fmt.Sprintf("hl=%d", element.HeaderLen)
	depthStr := fmt.Sprintf("d=%d", element.Depth)
	offsetStr := fmt.Sprintf("%d:", element.Offset)

	constructedStr := "prim"
	if element.IsCompound {
		constructedStr = "cons"
	}

	line := fmt.Sprintf("%8s%s %s %s %s: %s",
		offsetStr, depthStr, headerStr, lengthStr, constructedStr, element.TagName)

	if element.Content != "" {
		line += fmt.Sprintf("  %s", element.Content)
	}

	fmt.Println(line)
}

// FileHandler handles file operations
type FileHandler struct{}

// LoadFile loads and memory-maps a file
func (fh FileHandler) LoadFile(filePath string) ([]byte, func() error, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, nil, fmt.Errorf("error opening file: %w", err)
	}

	stat, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, nil, fmt.Errorf("error getting file stats: %w", err)
	}

	fileSize := stat.Size()
	if fileSize < 4 {
		file.Close()
		return nil, nil, errors.New("file too small to contain ASN.1 structure")
	}

	data, err := syscall.Mmap(int(file.Fd()), 0, int(fileSize), syscall.PROT_READ, syscall.MAP_SHARED)
	if err != nil {
		file.Close()
		return nil, nil, fmt.Errorf("error memory-mapping file: %w", err)
	}

	cleanup := func() error {
		if err := syscall.Munmap(data); err != nil {
			file.Close()
			return err
		}
		return file.Close()
	}

	return data, cleanup, nil
}

// SaveToFile saves data to a file
func (fh FileHandler) SaveToFile(data []byte, filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	_, err = file.Write(data)
	if err != nil {
		return fmt.Errorf("failed to write data: %w", err)
	}

	return nil
}

// listSupportedAlgorithms displays all supported cryptographic algorithms and OIDs
func listSupportedAlgorithms() {
	fmt.Println("=== SUPPORTED CRYPTOGRAPHIC ALGORITHMS AND OIDs ===")
	fmt.Println()

	fmt.Println("📋 RSA Signature Algorithms:")
	rsaOids := []string{
		"1.2.840.113549.1.1.1", "1.2.840.113549.1.1.2", "1.2.840.113549.1.1.4",
		"1.2.840.113549.1.1.5", "1.2.840.113549.1.1.10", "1.2.840.113549.1.1.11",
		"1.2.840.113549.1.1.12", "1.2.840.113549.1.1.13", "1.2.840.113549.1.1.14",
		"1.2.840.113549.1.1.15", "1.2.840.113549.1.1.16",
	}
	for _, oid := range rsaOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🔐 ECDSA Signature Algorithms:")
	ecdsaOids := []string{
		"1.2.840.10045.2.1", "1.2.840.10045.4.1", "1.2.840.10045.4.3.1",
		"1.2.840.10045.4.3.2", "1.2.840.10045.4.3.3", "1.2.840.10045.4.3.4",
	}
	for _, oid := range ecdsaOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🔑 DSA Signature Algorithms:")
	dsaOids := []string{
		"1.2.840.10040.4.1", "1.2.840.10040.4.3", "2.16.840.1.101.3.4.3.1", "2.16.840.1.101.3.4.3.2",
	}
	for _, oid := range dsaOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🆕 EdDSA Algorithms:")
	eddsaOids := []string{"1.3.101.112", "1.3.101.113"}
	for _, oid := range eddsaOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n#️⃣ Hash Algorithms:")
	hashOids := []string{
		"1.2.840.113549.2.5", "1.3.14.3.2.26", "2.16.840.1.101.3.4.2.1",
		"2.16.840.1.101.3.4.2.2", "2.16.840.1.101.3.4.2.3", "2.16.840.1.101.3.4.2.4",
		"2.16.840.1.101.3.4.2.5", "2.16.840.1.101.3.4.2.6", "2.16.840.1.101.3.4.2.7",
		"2.16.840.1.101.3.4.2.8", "2.16.840.1.101.3.4.2.9", "2.16.840.1.101.3.4.2.10",
		"2.16.840.1.101.3.4.2.11", "2.16.840.1.101.3.4.2.12",
	}
	for _, oid := range hashOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n📐 Elliptic Curves:")
	curveOids := []string{
		"1.2.840.10045.3.1.1", "1.2.840.10045.3.1.7", "1.3.132.0.34",
		"1.3.132.0.35", "1.3.132.0.10", "1.2.840.10045.3.1.2",
		"1.2.840.10045.3.1.3", "1.2.840.10045.3.1.4", "1.2.840.10045.3.1.5",
		"1.2.840.10045.3.1.6",
	}
	for _, oid := range curveOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🔮 Post-Quantum Algorithms:")
	pqOids := []string{
		"2.16.840.1.101.3.4.3.17", "2.16.840.1.101.3.4.3.18", "2.16.840.1.101.3.4.3.19",
		"1.3.6.1.4.1.2.267.12.4.4", "1.3.6.1.4.1.2.267.12.6.5",
		"2.16.840.1.101.3.4.3.20", "2.16.840.1.101.3.4.3.21", "2.16.840.1.101.3.4.3.22",
	}
	for _, oid := range pqOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🇷🇺 GOST Algorithms (Russian):")
	gostOids := []string{
		"1.2.643.2.2.19", "1.2.643.7.1.1.1.1", "1.2.643.7.1.1.1.2",
		"1.2.643.2.2.3", "1.2.643.7.1.1.3.2", "1.2.643.7.1.1.3.3",
		"1.2.643.2.2.9", "1.2.643.7.1.1.2.2", "1.2.643.7.1.1.2.3",
		"1.2.643.2.2.21", "1.2.643.7.1.1.5.1", "1.2.643.7.1.1.5.2",
	}
	for _, oid := range gostOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🇨🇳 Chinese SM Algorithms:")
	smOids := []string{
		"1.2.156.10197.1.301", "1.2.156.10197.1.401",
		"1.2.156.10197.1.104.1", "1.2.156.10197.1.104.2",
	}
	for _, oid := range smOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🇯🇵 Japanese Camellia Algorithms:")
	camelliaOids := []string{
		"1.2.392.200011.61.1.1.1.2", "1.2.392.200011.61.1.1.1.3", "1.2.392.200011.61.1.1.1.4",
	}
	for _, oid := range camelliaOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🏢 Microsoft Specific:")
	msOids := []string{
		"1.3.6.1.4.1.311.2.1.4", "1.3.6.1.4.1.311.2.1.15", "1.3.6.1.4.1.311.10.3.6",
		"1.3.6.1.4.1.311.10.3.1", "1.3.6.1.4.1.311.10.3.4", "1.3.6.1.4.1.311.20.2.2",
		"1.3.6.1.4.1.311.21.19", "1.3.6.1.4.1.311.21.20",
	}
	for _, oid := range msOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🔐 FIDO/WebAuthn:")
	fidoOids := []string{
		"1.3.6.1.4.1.45724.1.1.4", "1.3.6.1.4.1.45724.2.1.1",
		"1.3.101.110", "1.3.101.111",
	}
	for _, oid := range fidoOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n📦 PKCS#7/CMS Content Types:")
	pkcs7Oids := []string{
		"1.2.840.113549.1.7.1", "1.2.840.113549.1.7.2", "1.2.840.113549.1.7.3",
		"1.2.840.113549.1.7.4", "1.2.840.113549.1.7.5", "1.2.840.113549.1.7.6",
	}
	for _, oid := range pkcs7Oids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Println("\n🏷️  Distinguished Name Attributes:")
	dnOids := []string{
		"2.5.4.3", "2.5.4.4", "2.5.4.5", "2.5.4.6", "2.5.4.7", "2.5.4.8",
		"2.5.4.9", "2.5.4.10", "2.5.4.11", "2.5.4.12", "2.5.4.42", "2.5.4.43",
		"2.5.4.44", "2.5.4.46", "2.5.4.65", "1.2.840.113549.1.9.1",
	}
	for _, oid := range dnOids {
		if name, exists := oidNames[oid]; exists {
			fmt.Printf("  %s → %s\n", oid, name)
		}
	}

	fmt.Printf("\nTotal supported OIDs: %d\n", len(oidNames))
	fmt.Println("\nℹ️  This tool searches for ASN.1 signature structures in binary files")
	fmt.Println("   and validates the presence of required certificate fields.")
}

// parses command line arguments
func parseArgs() (*Config, error) {
	config := &Config{}
	flag.BoolVar(&config.SaveFile, "s", false, "save extracted signature to file (required for file output)")
	flag.StringVar(&config.OutputFile, "o", "signature.der", "output filename when using -s flag")
	flag.BoolVar(&config.ListAlgorithms, "list", false, "display all supported cryptographic algorithms and OIDs")
	flag.BoolVar(&config.ShowVersion, "v", false, "display program version")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "autograph-pls - ASN.1 Signature Parser and Validator\n")
		fmt.Fprintf(os.Stderr, "\nUsage: %s [options] <file_path>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nDESCRIPTION:\n")
		fmt.Fprintf(os.Stderr, "  Searches for ASN.1 signature structures (0x30 0x82) from the end of files backwards,\n")
		fmt.Fprintf(os.Stderr, "  validates certificate fields, recognizes cryptographic algorithms, and displays\n")
		fmt.Fprintf(os.Stderr, "  comprehensive ASN.1 structure information. Supports RSA, ECDSA, DSA, EdDSA,\n")
		fmt.Fprintf(os.Stderr, "  post-quantum algorithms, and various hash functions.\n")
		fmt.Fprintf(os.Stderr, "\nOPTIONS:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nEXAMPLES:\n")
		fmt.Fprintf(os.Stderr, "  %s myfile.efi                    # Analyze signature (display only)\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -s myfile.exe                # Extract signature to signature.der\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -s -o custom.der myfile.exe  # Extract signature to custom.der\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -list                        # Show all supported algorithms\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -v                           # Show program version\n", os.Args[0])
	}
	flag.Parse()

	// Handle list algorithms flag
	if config.ListAlgorithms || config.ShowVersion {
		return config, nil
	}

	args := flag.Args()
	if len(args) != 1 {
		return nil, errors.New("please provide exactly one file path")
	}

	config.FilePath = args[0]
	return config, nil
}

func main() {
	// Add panic recovery to handle crashes gracefully
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("\nCRITICAL ERROR: Program crashed while processing file\n")
			fmt.Printf("Error details: %v\n", r)
			fmt.Printf("\nThis typically happens when processing malformed or corrupted files.\n")
			fmt.Printf("The file may contain invalid ASN.1 structures or corrupted data.\n")
			fmt.Printf("\nPlease check:\n")
			fmt.Printf("1. File is not corrupted or truncated\n")
			fmt.Printf("2. File actually contains ASN.1 signature data\n")
			fmt.Printf("3. File is not a binary file without signatures\n")
			os.Exit(2)
		}
	}()

	config, err := parseArgs()
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		flag.Usage()
		os.Exit(1)
	}

	// Handle list algorithms option
	if config.ListAlgorithms {
		listSupportedAlgorithms()
		return
	}

	// Handle version flag
	if config.ShowVersion {
		fmt.Printf("autograph-pls version %s\n", version)
		return
	}

	fileHandler := FileHandler{}
	data, cleanup, err := fileHandler.LoadFile(config.FilePath)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
	defer func() {
		if err := cleanup(); err != nil {
			fmt.Printf("Warning: failed to cleanup file resources: %v\n", err)
		}
	}()

	fmt.Printf("Analyzing file: %s\n", config.FilePath)
	fmt.Printf("File size: %d bytes\n", len(data))
	fmt.Println("========================================")

	// Validate input data before processing
	if len(data) < 10 {
		fmt.Printf("Error: File too small (%d bytes) to contain meaningful ASN.1 signatures\n", len(data))
		os.Exit(1)
	}

	parser := NewSignatureParser(data)

	// Wrap signature finding in additional error handling
	var raw *asn1.RawValue
	var offset int
	func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("Error during signature search: %v\n", r)
				fmt.Printf("File appears to contain malformed ASN.1 data\n")
				os.Exit(1)
			}
		}()

		var findErr error
		raw, offset, findErr = parser.FindValidSignature()
		if findErr != nil {
			fmt.Printf("Error: %v\n", findErr)
			fmt.Printf("\nTroubleshooting suggestions:\n")
			fmt.Printf("1. Verify this file contains digital signatures\n")
			fmt.Printf("2. Check if file is corrupted or truncated\n")
			fmt.Printf("3. Ensure file format supports embedded signatures\n")
			os.Exit(1)
		}
	}()

	if raw == nil || raw.FullBytes == nil {
		fmt.Printf("Error: No valid signature data found\n")
		os.Exit(1)
	}

	fmt.Printf("Valid ASN.1 signature found at offset %d\n", offset)
	fmt.Printf("Structure size: %d bytes\n", len(raw.FullBytes))

	// Display validation results with error handling
	var validation SignatureValidation
	var keySize int
	func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("Warning: Error during signature validation: %v\n", r)
				fmt.Printf("Continuing with partial analysis...\n")
			}
		}()
		validation = parser.validateSignatureFields(raw.FullBytes)
		keySize = parser.calculateKeySize(raw.FullBytes, 0)
	}()

	results := DisplayResults{
		Validation: validation,
		KeySize:    keySize,
		Offset:     offset,
		Size:       len(raw.FullBytes),
	}
	results.Print()

	fmt.Println("========================================")

	// Display ASN.1 structure with enhanced error handling
	displayer := ASN1Displayer{}
	func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("Error displaying ASN.1 structure: %v\n", r)
				fmt.Printf("Showing hex dump instead...\n")
				if len(raw.FullBytes) > 256 {
					fmt.Printf("Raw data (first 256 bytes): %s...\n", hex.EncodeToString(raw.FullBytes[:256]))
				} else {
					fmt.Printf("Raw data (hex): %s\n", hex.EncodeToString(raw.FullBytes))
				}
			}
		}()

		if err := displayer.Display(raw.FullBytes, offset); err != nil {
			fmt.Printf("Error parsing ASN.1 structure: %v\n", err)
			if len(raw.FullBytes) > 256 {
				fmt.Printf("Raw data (first 256 bytes): %s...\n", hex.EncodeToString(raw.FullBytes[:256]))
			} else {
				fmt.Printf("Raw data (hex): %s\n", hex.EncodeToString(raw.FullBytes))
			}
		}
	}()

	fmt.Printf("Key size calculation: ")
	if keySize > 0 {
		fmt.Printf("%d bits\n", keySize)
	} else {
		fmt.Printf("N/A (no OCTET STRING found as final element)\n")
	}

	fmt.Println("========================================")

	// Save to file if requested with error handling
	if config.SaveFile {
		filename := config.OutputFile
		func() {
			defer func() {
				if r := recover(); r != nil {
					fmt.Printf("Error saving to file: %v\n", r)
					return
				}
			}()

			if err := fileHandler.SaveToFile(raw.FullBytes, filename); err != nil {
				fmt.Printf("Error saving to file: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("ASN.1 structure saved to: %s\n", filename)
		}()
	}
}

// parseASN1Element parses a single ASN.1 element
func parseASN1Element(data []byte, depth int, offset int) (ASN1Element, int, error) {
	// Prevent parsing at excessive depths
	if depth > MaxRecursionDepth {
		return ASN1Element{}, 0, errors.New("maximum parsing depth exceeded")
	}

	if len(data) < 2 {
		return ASN1Element{}, 0, errors.New("insufficient data for ASN.1 element")
	}

	element := ASN1Element{
		Depth:  depth,
		Offset: offset,
	}

	// Parse tag
	tagByte := data[0]
	element.Class = int((tagByte & 0xC0) >> 6)
	element.IsCompound = (tagByte & 0x20) != 0
	element.Tag = int(tagByte & 0x1F)

	bytesRead := 1

	// Parse length
	lengthByte := data[1]
	bytesRead++

	if lengthByte&0x80 == 0 {
		// Short form
		element.Length = int(lengthByte)
		element.HeaderLen = bytesRead
	} else {
		// Long form
		lengthOctets := int(lengthByte & 0x7F)
		if lengthOctets == 0 {
			return element, 0, errors.New("indefinite length not supported")
		}
		if len(data) < bytesRead+lengthOctets {
			return element, 0, errors.New("insufficient data for length octets")
		}

		element.Length = 0
		for i := 0; i < lengthOctets; i++ {
			if bytesRead >= len(data) {
				return element, 0, errors.New("insufficient data for length octets")
			}
			element.Length = (element.Length << 8) | int(data[bytesRead])
			bytesRead++
			// Check for unreasonably large lengths that could cause overflow or DoS
			if element.Length < 0 || element.Length > 50*1024*1024 { // 50MB limit
				return element, 0, errors.New("invalid or excessive length value")
			}
		}
		element.HeaderLen = bytesRead
	}

	// Set tag name and content
	element.TagName = getTagName(element.Tag, element.Class, element.IsCompound)

	if !element.IsCompound && element.Length > 0 && len(data) >= element.HeaderLen+element.Length {
		// Additional bounds check for content formatting
		contentStart := element.HeaderLen
		contentEnd := contentStart + element.Length
		if contentStart >= 0 && contentEnd >= 0 && contentStart <= len(data) && contentEnd <= len(data) && contentStart <= contentEnd {
			content := data[contentStart:contentEnd]
			element.Content = formatPrimitiveContent(element.Tag, content)
		}
	}

	totalBytes := element.HeaderLen + element.Length
	if totalBytes > len(data) {
		return element, 0, errors.New("element extends beyond available data")
	}

	return element, totalBytes, nil
}

// getTagName returns a human-readable name for the ASN.1 tag
func getTagName(tag int, class int, isCompound bool) string {
	// Handle different tag classes
	switch class {
	case 0: // Universal class
		return getUniversalTagName(tag, isCompound)
	case 1: // Application class
		if isCompound {
			return fmt.Sprintf("APPLICATION [%d]", tag)
		}
		return fmt.Sprintf("APPLICATION [%d]", tag)
	case 2: // Context-specific class
		return getContextSpecificTagName(tag, isCompound)
	case 3: // Private class
		if isCompound {
			return fmt.Sprintf("PRIVATE [%d]", tag)
		}
		return fmt.Sprintf("PRIVATE [%d]", tag)
	default:
		return fmt.Sprintf("UNKNOWN CLASS [%d] TAG [%d]", class, tag)
	}
}

// getUniversalTagName returns names for universal ASN.1 tags
func getUniversalTagName(tag int, isCompound bool) string {
	if isCompound {
		switch tag {
		case TagSequence:
			return "SEQUENCE"
		case TagSet:
			return "SET"
		default:
			return fmt.Sprintf("CONSTRUCTED [%d]", tag)
		}
	} else {
		switch tag {
		case TagBoolean:
			return "BOOLEAN"
		case TagInteger:
			return "INTEGER"
		case TagBitString:
			return "BIT STRING"
		case TagOctetString:
			return "OCTET STRING"
		case TagNull:
			return "NULL"
		case TagObjectID:
			return "OBJECT IDENTIFIER"
		case TagObjectDescriptor:
			return "ObjectDescriptor"
		case TagExternal:
			return "EXTERNAL"
		case TagReal:
			return "REAL"
		case TagEnumerated:
			return "ENUMERATED"
		case TagEmbeddedPDV:
			return "EMBEDDED PDV"
		case TagUTF8String:
			return "UTF8String"
		case TagRelativeOID:
			return "RELATIVE-OID"
		case TagNumericString:
			return "NumericString"
		case TagPrintable:
			return "PrintableString"
		case TagT61String:
			return "T61String"
		case TagVideotexString:
			return "VideotexString"
		case TagIA5String:
			return "IA5String"
		case TagUTCTime:
			return "UTCTime"
		case TagGeneralTime:
			return "GeneralizedTime"
		case TagGraphicString:
			return "GraphicString"
		case TagVisibleString:
			return "VisibleString"
		case TagGeneralString:
			return "GeneralString"
		case TagUniversalString:
			return "UniversalString"
		case TagCharacterString:
			return "CHARACTER STRING"
		case TagBMPString:
			return "BMPString"
		default:
			return fmt.Sprintf("PRIMITIVE [%d]", tag)
		}
	}
}

// getContextSpecificTagName returns names for common context-specific tags in X.509 and CMS
func getContextSpecificTagName(tag int, isCompound bool) string {
	// Common X.509 certificate context-specific tags
	contextTags := map[int]string{
		0:  "version/keyUsage",                 // Version in TBSCertificate or keyUsage in extensions
		1:  "issuerUniqueID/subjectAltName",    // IssuerUniqueID or subjectAltName extension
		2:  "subjectUniqueID/basicConstraints", // SubjectUniqueID or basicConstraints extension
		3:  "extensions/keyIdentifier",         // Extensions in TBSCertificate or key identifier
		4:  "directoryName",                    // Directory name in GeneralName
		5:  "ediPartyName",                     // EDI party name in GeneralName
		6:  "uniformResourceIdentifier",        // URI in GeneralName
		7:  "iPAddress",                        // IP address in GeneralName
		8:  "registeredID",                     // Registered ID in GeneralName
		9:  "otherName",                        // Other name form
		10: "certificatePolicies",              // Certificate policies extension
		11: "policyMappings",                   // Policy mappings extension
		12: "subjectDirectoryAttributes",       // Subject directory attributes
		13: "nameConstraints",                  // Name constraints extension
		14: "policyConstraints",                // Policy constraints extension
		15: "extKeyUsage",                      // Extended key usage extension
	}

	if name, exists := contextTags[tag]; exists {
		if isCompound {
			return fmt.Sprintf("CONTEXT [%d] (%s)", tag, name)
		}
		return fmt.Sprintf("CONTEXT [%d] (%s)", tag, name)
	}

	// Fallback for unknown context-specific tags
	if isCompound {
		return fmt.Sprintf("CONTEXT [%d]", tag)
	}
	return fmt.Sprintf("CONTEXT [%d]", tag)
}

// formats the content of primitive ASN.1 elements
func formatPrimitiveContent(tag int, content []byte) string {
	switch tag {
	case TagBoolean: // BOOLEAN
		if len(content) == 1 {
			if content[0] == 0 {
				return "FALSE"
			}
			return "TRUE"
		}
		return hex.EncodeToString(content)

	case TagInteger: // INTEGER
		if len(content) <= 8 {
			// Small integers - show as decimal and hex
			var value int64
			for _, b := range content {
				value = (value << 8) | int64(b)
			}
			if len(content) > 0 && content[0]&0x80 != 0 {
				// Handle negative numbers
				for i := len(content); i < 8; i++ {
					value |= int64(0xFF) << (8 * (7 - i))
				}
			}
			return fmt.Sprintf("%d (0x%X)", value, content)
		}
		// Large integers - show as hex
		return hex.EncodeToString(content)

	case TagBitString: // BIT STRING
		if len(content) > 0 {
			unusedBits := content[0]
			data := content[1:]
			if len(data) > 32 {
				return fmt.Sprintf("unused bits: %d, data: %s... (%d bytes)", unusedBits, hex.EncodeToString(data[:32]), len(data))
			}
			return fmt.Sprintf("unused bits: %d, data: %s", unusedBits, hex.EncodeToString(data))
		}
		return hex.EncodeToString(content)

	case TagOctetString: // OCTET STRING
		if len(content) > 32 {
			return fmt.Sprintf("%s... (%d bytes)", hex.EncodeToString(content[:32]), len(content))
		}
		return hex.EncodeToString(content)

	case TagNull: // NULL
		return ""

	case TagObjectID: // OBJECT IDENTIFIER
		oid := parseOID(content)
		if name, exists := oidNames[oid]; exists {
			return fmt.Sprintf("%s (%s)", oid, name)
		}
		return oid

	case TagReal: // REAL
		// Simple representation for REAL values - could be enhanced for proper IEEE 754 decoding
		if len(content) > 32 {
			return fmt.Sprintf("REAL: %s... (%d bytes)", hex.EncodeToString(content[:32]), len(content))
		}
		return fmt.Sprintf("REAL: %s", hex.EncodeToString(content))

	case TagEnumerated: // ENUMERATED
		if len(content) <= 8 {
			var value int64
			for _, b := range content {
				value = (value << 8) | int64(b)
			}
			return fmt.Sprintf("ENUM(%d)", value)
		}
		return fmt.Sprintf("ENUM: %s", hex.EncodeToString(content))

	case TagRelativeOID: // RELATIVE-OID
		// Similar to OID but without the first two arcs
		var oid []string
		i := 0
		for i < len(content) {
			var value uint64
			for i < len(content) {
				b := content[i]
				i++
				value = (value << 7) | uint64(b&0x7F)
				if b&0x80 == 0 {
					break
				}
			}
			oid = append(oid, fmt.Sprintf("%d", value))
		}
		return strings.Join(oid, ".")

	case TagObjectDescriptor: // ObjectDescriptor
		return fmt.Sprintf("ObjectDescriptor: %q", string(content))

	case TagExternal: // EXTERNAL
		return fmt.Sprintf("EXTERNAL (%d bytes)", len(content))

	case TagEmbeddedPDV: // EMBEDDED PDV
		return fmt.Sprintf("EMBEDDED PDV (%d bytes)", len(content))

	// String types
	case TagUTF8String, TagPrintable, TagT61String, TagIA5String,
		TagNumericString, TagVideotexString, TagGraphicString,
		TagVisibleString, TagGeneralString: // Various string types
		return fmt.Sprintf("%q", string(content))

	case TagUniversalString: // UniversalString (4-byte chars)
		if len(content)%4 != 0 {
			return fmt.Sprintf("Invalid UniversalString: %s", hex.EncodeToString(content))
		}
		return fmt.Sprintf("UniversalString: %s", hex.EncodeToString(content))

	case TagBMPString: // BMPString (2-byte chars)
		if len(content)%2 != 0 {
			return fmt.Sprintf("Invalid BMPString: %s", hex.EncodeToString(content))
		}
		return fmt.Sprintf("BMPString: %s", hex.EncodeToString(content))

	case TagCharacterString: // CHARACTER STRING
		return fmt.Sprintf("CHARACTER STRING (%d bytes)", len(content))

	// Time types
	case TagUTCTime, TagGeneralTime: // Time types
		return fmt.Sprintf("%q", string(content))

	default:
		if len(content) > 32 {
			return fmt.Sprintf("%s... (%d bytes)", hex.EncodeToString(content[:32]), len(content))
		}
		return hex.EncodeToString(content)
	}
}

// parses an ASN.1 OBJECT IDENTIFIER
func parseOID(content []byte) string {
	if len(content) == 0 {
		return ""
	}

	var oid []string

	// First subidentifier encodes first two arc values
	if len(content) > 0 {
		first := content[0]
		oid = append(oid, fmt.Sprintf("%d", first/40))
		oid = append(oid, fmt.Sprintf("%d", first%40))
	}

	// Remaining subidentifiers
	i := 1
	for i < len(content) {
		var value uint64
		for i < len(content) {
			b := content[i]
			i++
			value = (value << 7) | uint64(b&0x7F)
			if b&0x80 == 0 {
				break
			}
		}
		oid = append(oid, fmt.Sprintf("%d", value))
	}

	return strings.Join(oid, ".")
}
