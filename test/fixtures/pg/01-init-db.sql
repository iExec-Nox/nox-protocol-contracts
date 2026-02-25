-- Underlying storage table (named separately to avoid trigger recursion).
CREATE TABLE IF NOT EXISTS handles_store (
    handle TEXT PRIMARY KEY,
    ciphertext TEXT NOT NULL,
    public_key TEXT NOT NULL,
    nonce TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- View that the gateway uses (transparent for SELECT; auto-updatable for UPDATE/DELETE).
CREATE OR REPLACE VIEW handles AS
    SELECT handle, ciphertext, public_key, nonce, created_at FROM handles_store;

-- Redirect INSERT on the view to an UPSERT on the underlying table.
-- Duplicate handles can occur when Nox.toEuint256(x) is called twice with the same
-- value in one transaction (deterministic encryption produces identical handles).
-- ON CONFLICT DO UPDATE ensures INSERT RETURNING always yields a row, so the
-- gateway's fetch_one() never gets "no rows returned by a query that expected
-- to return at least one row".
CREATE OR REPLACE FUNCTION handles_insert_upsert_fn()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure created_at is not NULL before inserting and before returning.
    -- The DEFAULT CURRENT_TIMESTAMP does not apply to NEW in INSTEAD OF triggers,
    -- so if the caller omitted created_at it arrives as NULL. The gateway decodes
    -- this column as a non-nullable type, so returning NULL causes a decode error.
    NEW.created_at := COALESCE(NEW.created_at, CURRENT_TIMESTAMP);
    INSERT INTO handles_store (handle, ciphertext, public_key, nonce, created_at)
    VALUES (NEW.handle, NEW.ciphertext, NEW.public_key, NEW.nonce, NEW.created_at)
    ON CONFLICT (handle) DO UPDATE
    SET ciphertext = EXCLUDED.ciphertext,
        public_key = EXCLUDED.public_key,
        nonce = EXCLUDED.nonce;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handles_insert_upsert
    INSTEAD OF INSERT ON handles
    FOR EACH ROW EXECUTE FUNCTION handles_insert_upsert_fn();
