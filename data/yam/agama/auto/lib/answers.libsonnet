{
    questions_decrypt_old(decrypt_password=''):: {
        class: "storage.luks_activation",
        answer: "decrypt",
        password: decrypt_password
    },
    questions_import_gpg_old():: {
        class: "software.import_gpg",
        answer: "Trust"
    },
    questions_activate_multipath_old():: {
        class: "storage.activate_multipath",
        answer: "yes"
    },
    questions_decrypt(decrypt_password=''):: {
        class: "luksActivation",
        action: "decrypt",
        value: decrypt_password
    },
    questions_import_gpg():: {
        class: "importGpg",
        action: "Trust"
    },
    questions_activate_multipath():: {
        class: "multipathActivation",
        action: "yes"
    },
}
