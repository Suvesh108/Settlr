package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Configurable CORS
	},
}

type EventMessage struct {
	Event     string      `json:"event"`
	GroupID   string      `json:"group_id"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
}

type Client struct {
	Hub     *Hub
	Conn    *websocket.Conn
	UserID  string
	GroupID string
	Send    chan []byte
}

type BroadcastMessage struct {
	GroupID string
	Payload []byte
}

type Hub struct {
	// rooms maps groupID to active clients in that group
	rooms      map[string]map[*Client]bool
	register   chan *Client
	unregister chan *Client
	broadcast  chan BroadcastMessage
	mu         sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		rooms:      make(map[string]map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan BroadcastMessage, 256),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if h.rooms[client.GroupID] == nil {
				h.rooms[client.GroupID] = make(map[*Client]bool)
			}
			h.rooms[client.GroupID][client] = true
			h.mu.Unlock()
			log.Printf("[WS] Client %s joined group room %s", client.UserID, client.GroupID)

		case client := <-h.unregister:
			h.mu.Lock()
			if clients, ok := h.rooms[client.GroupID]; ok {
				if _, exists := clients[client]; exists {
					delete(clients, client)
					close(client.Send)
					if len(clients) == 0 {
						delete(h.rooms, client.GroupID)
					}
				}
			}
			h.mu.Unlock()
			log.Printf("[WS] Client %s left group room %s", client.UserID, client.GroupID)

		case msg := <-h.broadcast:
			h.mu.RLock()
			clients := h.rooms[msg.GroupID]
			for client := range clients {
				select {
				case client.Send <- msg.Payload:
				default:
					close(client.Send)
					delete(clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) Broadcast(groupID string, event string, data interface{}) {
	msg := EventMessage{
		Event:     event,
		GroupID:   groupID,
		Data:      data,
		Timestamp: time.Now(),
	}
	bytes, err := json.Marshal(msg)
	if err != nil {
		log.Printf("[WS] Error marshaling broadcast event: %v", err)
		return
	}
	h.broadcast <- BroadcastMessage{
		GroupID: groupID,
		Payload: bytes,
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		_ = c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				_ = c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			_, _ = w.Write(message)

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		c.Hub.unregister <- c
		_ = c.Conn.Close()
	}()

	c.Conn.SetReadLimit(4096)
	_ = c.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.Conn.SetPongHandler(func(string) error {
		_ = c.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, _, err := c.Conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

// ServeWs upgrades HTTP to WebSocket and registers the client into the group room
func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request, userID, groupID string) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS] Upgrade error: %v", err)
		return
	}

	client := &Client{
		Hub:     hub,
		Conn:    conn,
		UserID:  userID,
		GroupID: groupID,
		Send:    make(chan []byte, 256),
	}

	client.Hub.register <- client

	go client.writePump()
	go client.readPump()
}
