/**
 * Zero-Knowledge Client-Side Encryption Utilities
 * Uses standard Web Cryptography API (AES-GCM 256-bit)
 * Zero external libraries needed; natively available in all modern browsers and WebViews.
 */

// Generate a random 256-bit symmetric key for a newly created group
export async function generateGroupKey(): Promise<string> {
  const key = await window.crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    true,
    ['encrypt', 'decrypt']
  );
  const exported = await window.crypto.subtle.exportKey('raw', key);
  return buf2hex(exported);
}

// Convert a hex string group key into a CryptoKey object
async function importKey(hexKey: string): Promise<CryptoKey> {
  const rawKey = hex2buf(hexKey);
  return await window.crypto.subtle.importKey(
    'raw',
    rawKey,
    { name: 'AES-GCM' },
    false,
    ['encrypt', 'decrypt']
  );
}

// Encrypt any JSON-serializable payload (expense, settlement, note)
export async function encryptPayload<T>(
  hexKey: string,
  data: T
): Promise<{ ciphertext: string; iv: string }> {
  const cryptoKey = await importKey(hexKey);
  const iv = window.crypto.getRandomValues(new Uint8Array(12)); // standard 96-bit IV for AES-GCM
  const encoded = new TextEncoder().encode(JSON.stringify(data));

  const encryptedBuf = await window.crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    cryptoKey,
    encoded
  );

  return {
    ciphertext: buf2hex(encryptedBuf),
    iv: buf2hex(iv.buffer),
  };
}

// Decrypt ciphertext using the client's local group key
export async function decryptPayload<T>(
  hexKey: string,
  ciphertextHex: string,
  ivHex: string
): Promise<T> {
  const cryptoKey = await importKey(hexKey);
  const iv = new Uint8Array(hex2buf(ivHex));
  const encryptedBuf = hex2buf(ciphertextHex);

  const decryptedBuf = await window.crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    cryptoKey,
    encryptedBuf
  );

  const decoded = new TextDecoder().decode(decryptedBuf);
  return JSON.parse(decoded) as T;
}

// Helpers
function buf2hex(buffer: ArrayBuffer): string {
  return Array.prototype.map
    .call(new Uint8Array(buffer), (x: number) => ('00' + x.toString(16)).slice(-2))
    .join('');
}

function hex2buf(hexString: string): ArrayBuffer {
  const match = hexString.match(/[\da-f]{2}/gi);
  if (!match) return new ArrayBuffer(0);
  return new Uint8Array(match.map((h) => parseInt(h, 16))).buffer;
}
