import { useEffect, useRef } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useAuthStore } from '../store/authStore';
import { pullAndDecryptEnvelopes } from '../services/syncMailbox';

export function useGroupSync(groupId: string | null) {
  const queryClient = useQueryClient();
  const token = useAuthStore((state) => state.token);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    if (!groupId || !token) {
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      return;
    }

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/groups/${groupId}?token=${token}`;

    let socket: WebSocket;
    let reconnectTimeout: ReturnType<typeof setTimeout>;

    const currentGroupId = groupId;
    function connect() {
      socket = new WebSocket(wsUrl);
      wsRef.current = socket;

      socket.onopen = () => {
        console.log(`[WebSocket] Connected to group room ${currentGroupId}`);
        // Pull encrypted mailbox envelopes and catch up
        pullAndDecryptEnvelopes(currentGroupId).catch(() => {});

        // Catch-up refresh: invalidate and pull fresh state upon (re)connect
        queryClient.invalidateQueries({ queryKey: ['groups'] });
        queryClient.invalidateQueries({ queryKey: ['group', groupId] });
        queryClient.invalidateQueries({ queryKey: ['expenses', groupId] });
        queryClient.invalidateQueries({ queryKey: ['balances', groupId] });
        queryClient.invalidateQueries({ queryKey: ['pairwise', groupId] });
        queryClient.invalidateQueries({ queryKey: ['settlements', groupId] });
        queryClient.invalidateQueries({ queryKey: ['recommended', groupId] });
        queryClient.invalidateQueries({ queryKey: ['activity', groupId] });
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          console.log('[WebSocket] Event received:', data.event, data);

          if (data.event === 'sync.envelopes_pushed') {
            pullAndDecryptEnvelopes(currentGroupId).catch(() => {});
          }

          // Invalidate server queries immediately
          queryClient.invalidateQueries({ queryKey: ['groups'] });
          queryClient.invalidateQueries({ queryKey: ['group', groupId] });
          queryClient.invalidateQueries({ queryKey: ['expenses', groupId] });
          queryClient.invalidateQueries({ queryKey: ['balances', groupId] });
          queryClient.invalidateQueries({ queryKey: ['pairwise', groupId] });
          queryClient.invalidateQueries({ queryKey: ['settlements', groupId] });
          queryClient.invalidateQueries({ queryKey: ['recommended', groupId] });
          queryClient.invalidateQueries({ queryKey: ['activity', groupId] });
        } catch (e) {
          console.error('[WebSocket] Failed to parse message', e);
        }
      };

      socket.onclose = () => {
        console.log('[WebSocket] Connection closed. Reconnecting in 3s...');
        reconnectTimeout = setTimeout(connect, 3000);
      };

      socket.onerror = (err) => {
        console.error('[WebSocket] Error occurred', err);
        socket.close();
      };
    }

    connect();

    return () => {
      clearTimeout(reconnectTimeout);
      if (socket) {
        socket.onclose = null; // Prevent reconnect loop on unmount
        socket.close();
      }
    };
  }, [groupId, token, queryClient]);
}
