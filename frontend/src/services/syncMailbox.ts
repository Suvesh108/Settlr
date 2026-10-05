import { localDB } from '../db/localDB';
import { apiRequest } from './api';
import { encryptPayload, decryptPayload, generateGroupKey } from './crypto';

export interface SyncEnvelope {
  id: string;
  group_id: string;
  sender_id: string;
  device_id: string;
  ciphertext: string;
  iv: string;
  key_version: number;
  seq: number;
  created_at: string;
}

export interface SyncPayload {
  type: 'EXPENSE_CREATED' | 'SETTLEMENT_RECORDED' | 'SETTLEMENT_CONFIRMED';
  data: Record<string, unknown>;
  timestamp: number;
}

// Ensure the group has a cryptographic key stored locally on this device
export async function getOrCreateGroupKey(groupId: string): Promise<string> {
  const existing = await localDB.groupKeys.get(groupId);
  if (existing) {
    return existing.key_hex;
  }
  // Check if hash fragment in URL contains key from invite link
  if (window.location.hash.startsWith('#key=')) {
    const key = window.location.hash.replace('#key=', '');
    if (key.length >= 32) {
      await localDB.groupKeys.put({
        group_id: groupId,
        key_hex: key,
        created_at: Date.now(),
      });
      return key;
    }
  }

  // Generate new cryptographic key
  const newKey = await generateGroupKey();
  await localDB.groupKeys.put({
    group_id: groupId,
    key_hex: newKey,
    created_at: Date.now(),
  });
  return newKey;
}

// Push an encrypted envelope to the group mailbox
export async function pushEncryptedEvent(
  groupId: string,
  payload: SyncPayload
): Promise<void> {
  try {
    const key = await getOrCreateGroupKey(groupId);
    const encrypted = await encryptPayload(key, payload);

    const deviceId =
      localStorage.getItem('settlr_device_id') ||
      (() => {
        const id = 'dev_' + Math.random().toString(36).substring(2, 10);
        localStorage.setItem('settlr_device_id', id);
        return id;
      })();

    await apiRequest(`/groups/${groupId}/sync/push`, {
      method: 'POST',
      body: JSON.stringify({
        envelopes: [
          {
            device_id: deviceId,
            ciphertext: encrypted.ciphertext,
            iv: encrypted.iv,
            key_version: 1,
          },
        ],
      }),
    });
  } catch (err) {
    console.warn('[SyncMailbox] Background push warning:', err);
  }
}

// Pull new envelopes from the mailbox and decrypt locally
export async function pullAndDecryptEnvelopes(
  groupId: string
): Promise<SyncPayload[]> {
  try {
    const syncState = await localDB.syncState.get(groupId);
    const sinceSeq = syncState ? syncState.last_seq : 0;

    const res = await apiRequest<{ envelopes: SyncEnvelope[] }>(
      `/groups/${groupId}/sync/pull?since_seq=${sinceSeq}`
    );

    if (!res.envelopes || res.envelopes.length === 0) {
      return [];
    }

    const key = await getOrCreateGroupKey(groupId);
    const decryptedList: SyncPayload[] = [];
    let maxSeq = sinceSeq;

    for (const env of res.envelopes) {
      if (env.seq > maxSeq) {
        maxSeq = env.seq;
      }
      try {
        const decrypted = await decryptPayload<SyncPayload>(key, env.ciphertext, env.iv);
        decryptedList.push(decrypted);
      } catch (decErr) {
        console.warn('[SyncMailbox] Could not decrypt envelope #' + env.seq, decErr);
      }
    }

    // Advance device sequence marker
    await localDB.syncState.put({
      group_id: groupId,
      last_seq: maxSeq,
      last_synced_at: Date.now(),
    });

    return decryptedList;
  } catch (err) {
    console.warn('[SyncMailbox] Pull error:', err);
    return [];
  }
}
