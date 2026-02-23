CREATE TABLE IF NOT EXISTS handles (
    handle TEXT PRIMARY KEY,
    ciphertext TEXT NOT NULL,
    public_key TEXT NOT NULL,
    nonce TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
