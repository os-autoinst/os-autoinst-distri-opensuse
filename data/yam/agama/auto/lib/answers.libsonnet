{
    questions_decrypt(decrypt_password=''):: {
        policy: "auto",
        answers: [
            {
                class: "storage.luks_activation",
                answer: "decrypt",
                password: decrypt_password
            }
        ]
    }
}
