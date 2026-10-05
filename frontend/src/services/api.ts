import { useAuthStore } from '../store/authStore';
import { localDB } from '../db/localDB';

const API_BASE = '/api/v1';

function generateUUID(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

interface RequestOptions extends RequestInit {
  useIdempotency?: boolean;
  _isRetry?: boolean;
}

export async function apiRequest<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const token = useAuthStore.getState().token;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  if (options.useIdempotency && (!options.method || options.method === 'POST')) {
    headers['Idempotency-Key'] = generateUUID();
  }

  let response: Response;
  try {
    response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
    });
  } catch (netErr) {
    // OFFLINE / LOCAL-FIRST FALLBACK:
    if (endpoint === '/groups' && (!options.method || options.method === 'GET')) {
      const cached = await localDB.groups.toArray();
      if (cached.length > 0) return cached as unknown as T;
    }
    const expenseMatch = endpoint.match(/^\/groups\/([^/]+)\/expenses$/);
    if (expenseMatch && (!options.method || options.method === 'GET')) {
      const gId = expenseMatch[1];
      const cached = await localDB.expenses.where('group_id').equals(gId).toArray();
      if (cached.length > 0) return cached as unknown as T;
    }
    throw netErr;
  }

  const json = await response.json().catch(() => ({}));

  if (!response.ok || json.success === false) {
    const errorCode = json.error?.code || '';
    const msg = json.error?.message || response.statusText || 'Request failed';

    // If token expired or invalid and this isn't already the auth session endpoint, refresh session and retry once
    if (
      (response.status === 401 || errorCode === 'INVALID_TOKEN' || msg.toLowerCase().includes('token')) &&
      !endpoint.startsWith('/auth/session') &&
      !options._isRetry
    ) {
      try {
        const currentUser = useAuthStore.getState().user;
        const res = await fetch(`${API_BASE}/auth/session`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: currentUser?.name || 'User',
            email: currentUser?.email || 'user@local',
            default_currency: currentUser?.default_currency || 'INR',
          }),
        });
        const resJson = await res.json().catch(() => ({}));
        if (res.ok && resJson.data?.token) {
          useAuthStore.getState().setAuth(resJson.data, resJson.data.token);
          return apiRequest<T>(endpoint, { ...options, _isRetry: true });
        }
      } catch (refreshErr) {
        console.warn('Failed to auto-refresh session:', refreshErr);
      }
    }

    throw new Error(msg);
  }

  const data = json.data as T;

  // Asynchronously mirror successful responses to IndexedDB for local-first durability
  try {
    if (endpoint === '/groups' && (!options.method || options.method === 'GET') && Array.isArray(data)) {
      localDB.groups.bulkPut(data as any).catch(() => {});
    } else if (endpoint.endsWith('/expenses') && (!options.method || options.method === 'GET') && Array.isArray(data)) {
      localDB.expenses.bulkPut(data as any).catch(() => {});
    } else if (endpoint.endsWith('/settlements') && (!options.method || options.method === 'GET') && Array.isArray(data)) {
      localDB.settlements.bulkPut(data as any).catch(() => {});
    }
  } catch {
    // Ignore indexing errors in background
  }

  return data;
}
