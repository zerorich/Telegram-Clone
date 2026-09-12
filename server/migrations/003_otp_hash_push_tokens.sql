-- otp_codes.code stores a SHA-256 hex hash (code + pepper), not plaintext.
COMMENT ON COLUMN otp_codes.code IS 'SHA-256 hex hash of OTP code with server pepper';

ALTER TABLE otp_codes ALTER COLUMN code TYPE VARCHAR(128);

-- Push notification tokens for incoming calls/messages.
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token VARCHAR(512);
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_platform VARCHAR(32);
