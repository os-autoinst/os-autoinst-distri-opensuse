{
    questions_decrypt(decrypt_password=''):: {
        class: "storage.luks_activation",
        answer: "decrypt",
        password: decrypt_password
    },
    questions_import_gpg():: {
        class: "software.import_gpg",
        answer: "Trust"
   },
   questions_activate_multipath():: {
        class: "storage.activate_multipath",
        answer: "yes"
   },
}
