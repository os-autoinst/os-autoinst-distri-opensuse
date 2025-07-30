// C++ test
#include <iostream> // For std::cerr, std::cout
#include <string>   // For std::string
#include <assert.h> // For assert()
#include <stdio.h>  // For puts()

// Define the code unit width. For char strings (std::string), use 8.
// This means we'll be using the _8 suffixed functions and types.
#define PCRE2_CODE_UNIT_WIDTH 8

// Include the main PCRE2 header
#include <pcre2.h>

// --- Custom Simple PCRE2 Wrapper Class (mimicking pcrecpp::RE) ---
// This class encapsulates the PCRE2 C API details for simpler usage.
class SimplePcre2RE {
public:
    // Constructor: Compiles the regex pattern
    explicit SimplePcre2RE(const std::string& pattern_str) : re_(nullptr) {
        int errorcode;
        PCRE2_SIZE erroroffset;

        // Use the suffixed type PCRE2_SPTR8
        PCRE2_SPTR8 pcre2_pattern_str = (PCRE2_SPTR8)pattern_str.c_str();

        // Use the suffixed function pcre2_compile_8
        re_ = pcre2_compile_8(
            pcre2_pattern_str,
            PCRE2_ZERO_TERMINATED,
            0, // Options (e.g., PCRE2_CASELESS for case-insensitivity)
            &errorcode,
            &erroroffset,
            NULL // Compile context
        );

        if (re_ == nullptr) {
            // Use the suffixed type PCRE2_UCHAR8 and function pcre2_get_error_message_8
            PCRE2_UCHAR8 buffer[256];
            pcre2_get_error_message_8(errorcode, buffer, sizeof(buffer));
            std::cerr << "SimplePcre2RE: PCRE2 compilation failed for pattern '" << pattern_str
                      << "' at offset " << erroroffset << ": " << (char*)buffer << std::endl;
            // In a real application, you might throw an exception here
        }
    }

    // Destructor: Frees the compiled pattern
    ~SimplePcre2RE() {
        if (re_ != nullptr) {
            // Use the suffixed function pcre2_code_free_8
            pcre2_code_free_8(re_);
            re_ = nullptr;
        }
    }

    // FullMatch method: Checks if the entire subject string matches the pattern
    bool FullMatch(const std::string& subject_str) const {
        if (re_ == nullptr) {
            return false; // Pattern not compiled successfully
        }

        // Use the suffixed type PCRE2_SPTR8
        PCRE2_SPTR8 pcre2_subject_str = (PCRE2_SPTR8)subject_str.c_str();
        PCRE2_SIZE pcre2_subject_len = (PCRE2_SIZE)subject_str.length();

        // Use the suffixed type pcre2_match_data_8 and function pcre2_match_data_create_from_pattern_8
        pcre2_match_data_8 *match_data = pcre2_match_data_create_from_pattern_8(re_, NULL);
        if (match_data == nullptr) {
            std::cerr << "SimplePcre2RE::FullMatch: Failed to create match data for subject: " << subject_str << std::endl;
            return false;
        }

        // Perform the match using the suffixed function pcre2_match_8
        int rc = pcre2_match_8(
            re_,
            pcre2_subject_str,
            pcre2_subject_len,
            0, // Start offset (from beginning of string)
            0, // Options
            match_data,
            NULL // Match context
        );

        bool is_full_match = false;
        if (rc >= 0) {
            // Use the suffixed function pcre2_get_ovector_pointer_8
            PCRE2_SIZE *ovector = pcre2_get_ovector_pointer_8(match_data);
            // For a FullMatch, the entire subject must be matched from start to end.
            if (ovector[0] == 0 && (ovector[1] - ovector[0]) == pcre2_subject_len) {
                is_full_match = true;
            }
        } else if (rc != PCRE2_ERROR_NOMATCH) {
            // Use the suffixed type PCRE2_UCHAR8 and function pcre2_get_error_message_8
            PCRE2_UCHAR8 buffer[256];
            pcre2_get_error_message_8(rc, buffer, sizeof(buffer));
            std::cerr << "SimplePcre2RE::FullMatch: Matching error for subject '" << subject_str << "': " << (char*)buffer << std::endl;
        }

        // Free the match data using the suffixed function pcre2_match_data_free_8
        pcre2_match_data_free_8(match_data);
        return is_full_match;
    }

private:
    // Store the compiled pattern using the suffixed type pcre2_code_8
    pcre2_code_8* re_;
};
// --- End of Custom Simple PCRE2 Wrapper Class ---


// Your main function, now using the simple wrapper
int main() {
    // Instantiate our custom wrapper, just like pcrecpp::RE
    SimplePcre2RE re("h.*o");

    // Use the FullMatch method
    assert(re.FullMatch("hello"));
    assert(!re.FullMatch("Hello")); // Case-sensitive by default
    assert(!re.FullMatch("hello world"));

    puts("Simple PCRE2 wrapper worked!");
    return 0;
}
