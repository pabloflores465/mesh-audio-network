// Mesh Agent - Main entry point
// Handles mesh networking, master election, and streaming

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"runtime"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	MeshPort    = 4567
	MeshNetwork = "10.200.0.0/16"
)

// NodeInfo holds information about a mesh node
type NodeInfo struct {
	ID         string    `json:"id"`
	MAC        string    `json:"mac"`
	IP         string    `json:"ip"`
	CPU        float64   `json:"cpu"`
	RAM        uint64    `json:"ram"`
	Uptime     int64     `json:"uptime"`
	IsMaster   bool      `json:"is_master"`
	LastSeen   time.Time `json:"last_seen"`
	Songs      []string  `json:"songs"`
	SignalRSSI int       `json:"signal_rssi"`
}

// MeshAgent is the main mesh networking agent
type MeshAgent struct {
	ID          string
	MAC         string
	IP          string
	IsMaster    bool
	Peers       map[string]*NodeInfo
	Songs       []string
	CurrentSong string
	Mutex       sync.RWMutex
	ctx         context.Context
	cancel      context.CancelFunc
	startTime   int64
}

// NewMeshAgent creates a new mesh agent
func NewMeshAgent() *MeshAgent {
	ctx, cancel := context.WithCancel(context.Background())
	agent := &MeshAgent{
		ID:          getNodeID(),
		MAC:         getMACAddress(),
		IP:          getLocalIP(),
		Peers:       make(map[string]*NodeInfo),
		Songs:       loadNodeSongs(),
		ctx:         ctx,
		cancel:      cancel,
		startTime:   time.Now().Unix(),
	}
	go agent.startDiscovery()
	go agent.electMaster()
	return agent
}

// GetSystemResources returns CPU count and memory
func GetSystemResources() (cpu float64, ram uint64) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	return float64(runtime.NumCPU()), m.Sys
}

// Score calculates the master election score
func (n *NodeInfo) Score() float64 {
	return n.CPU*100 + float64(n.RAM)/1e9*50 + float64(n.Uptime)/3600*10
}

// startDiscovery listens for peer nodes
func (m *MeshAgent) startDiscovery() {
	addr, err := net.ResolveUDPAddr("udp", fmt.Sprintf(":%d", MeshPort))
	if err != nil {
		log.Fatal(err)
	}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	go m.broadcastPresence()

	buf := make([]byte, 4096)
	for {
		select {
		case <-m.ctx.Done():
			return
		default:
			conn.SetReadDeadline(time.Now().Add(1 * time.Second))
			n, peerAddr, err := conn.ReadFromUDP(buf)
			if err != nil {
				continue
			}
			var peer NodeInfo
			if err := json.Unmarshal(buf[:n], &peer); err != nil {
				continue
			}
			m.Mutex.Lock()
			peer.IP = peerAddr.IP.String()
			peer.LastSeen = time.Now()
			m.Peers[peer.ID] = &peer
			m.Mutex.Unlock()
		}
	}
}

// broadcastPresence announces this node to the mesh
func (m *MeshAgent) broadcastPresence() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	conn, err := net.DialUDP("udp", nil, &net.UDPAddr{
		IP:   net.IPv4(255, 255, 255, 255),
		Port: MeshPort,
	})
	if err != nil {
		log.Printf("Broadcast error: %v", err)
		return
	}
	defer conn.Close()

	for {
		select {
		case <-m.ctx.Done():
			return
		case <-ticker.C:
			cpu, ram := GetSystemResources()
			node := NodeInfo{
				ID:     m.ID,
				MAC:    m.MAC,
				IP:     m.IP,
				CPU:    cpu,
				RAM:    ram,
				Uptime: time.Now().Unix() - m.startTime,
				IsMaster: m.IsMaster,
				Songs: m.Songs,
			}
			data, _ := json.Marshal(node)
			conn.Write(data)
		}
	}
}

// electMaster performs master election based on resources
func (m *MeshAgent) electMaster() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			return
		case <-ticker.C:
			m.Mutex.Lock()
			
			// Add self to peer list for comparison
			cpu, ram := GetSystemResources()
			self := &NodeInfo{
				ID:     m.ID,
				CPU:    cpu,
				RAM:    ram,
				Uptime: time.Now().Unix() - m.startTime,
			}
			
			// Get all nodes including self
			nodes := make([]*NodeInfo, 0, len(m.Peers)+1)
			nodes = append(nodes, self)
			for _, p := range m.Peers {
				nodes = append(nodes, p)
			}
			
			// Sort by score (descending)
			sort.Slice(nodes, func(i, j int) bool {
				return nodes[i].Score() > nodes[j].Score()
			})
			
			// First node is master
			wasMaster := m.IsMaster
			m.IsMaster = nodes[0].ID == m.ID
			
			if m.IsMaster && !wasMaster {
				log.Println("🎖️ Elected as MASTER")
			} else if !m.IsMaster && wasMaster {
				log.Println("❌ Lost master status")
			}
			
			m.Mutex.Unlock()
		}
	}
}

// API handlers
func (m *MeshAgent) handleStatus(w http.ResponseWriter, r *http.Request) {
	m.Mutex.RLock()
	defer m.Mutex.RUnlock()

	cpu, ram := GetSystemResources()
	status := map[string]interface{}{
		"node_id":      m.ID,
		"is_master":    m.IsMaster,
		"peers_count":  len(m.Peers),
		"song_count":   len(m.Songs),
		"current_song": m.CurrentSong,
		"cpu_cores":    int(cpu),
		"ram_bytes":    ram,
	}

	json.NewEncoder(w).Encode(status)
}

func (m *MeshAgent) handleSetSong(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Song string `json:"song"`
		SongName string `json:"song_name"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	
	if req.SongName != "" {
		m.CurrentSong = req.SongName
	} else if req.Song != "" {
		m.CurrentSong = req.Song
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok", "song": m.CurrentSong})
}

func (m *MeshAgent) handlePeers(w http.ResponseWriter, r *http.Request) {
	m.Mutex.RLock()
	defer m.Mutex.RUnlock()
	
	peers := make([]NodeInfo, 0, len(m.Peers))
	for _, p := range m.Peers {
		peers = append(peers, *p)
	}
	json.NewEncoder(w).Encode(peers)
}

func (m *MeshAgent) handleSongs(w http.ResponseWriter, r *http.Request) {
	m.Mutex.RLock()
	defer m.Mutex.RUnlock()
	json.NewEncoder(w).Encode(m.Songs)
}

func (m *MeshAgent) handleMetrics(w http.ResponseWriter, r *http.Request) {
	m.Mutex.RLock()
	defer m.Mutex.RUnlock()

	metrics := map[string]interface{}{
		"node_id":        m.ID,
		"is_master":      m.IsMaster,
		"active_peers":   len(m.Peers),
		"local_songs":    len(m.Songs),
		"streaming_song":  m.CurrentSong,
		"tx_rate_mbps":    getTxRate(),
		"signal_dbm":      getSignalStrength(),
		"modulation":      getModulation(),
	}

	json.NewEncoder(w).Encode(metrics)
}

func (m *MeshAgent) handleHealth(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"service": "mesh-agent",
		"time": time.Now().Format(time.RFC3339),
	})
}

// StartAPI starts the HTTP API server
func (m *MeshAgent) StartAPI(addr string) {
	http.HandleFunc("/health", m.handleHealth)
	http.HandleFunc("/status", m.handleStatus)
	http.HandleFunc("/set-song", m.handleSetSong)
	http.HandleFunc("/peers", m.handlePeers)
	http.HandleFunc("/songs", m.handleSongs)
	http.HandleFunc("/metrics", m.handleMetrics)
	log.Printf("API listening on %s", addr)
	http.ListenAndServe(addr, nil)
}

// GetMetrics returns network metrics
func (m *MeshAgent) GetMetrics() map[string]interface{} {
	m.Mutex.RLock()
	defer m.Mutex.RUnlock()

	return map[string]interface{}{
		"node_id":         m.ID,
		"is_master":       m.IsMaster,
		"active_peers":    len(m.Peers),
		"local_songs":     len(m.Songs),
		"streaming_song":  m.CurrentSong,
		"tx_rate_mbps":    getTxRate(),
		"signal_dbm":      getSignalStrength(),
		"modulation":      getModulation(),
	}
}

func main() {
	log.SetFlags(0)
	log.Println("╔════════════════════════════════════════╗")
	log.Println("║   Mesh Audio Network Agent v1.0       ║")
	log.Println("╚════════════════════════════════════════╝")
	
	agent := NewMeshAgent()
	
	// Start API in background
	go agent.StartAPI(":8080")
	
	// Start streaming if master
	go agent.runStreaming()
	
	// Print status periodically
	go agent.printStatus()
	
	// Wait for signal
	<-make(chan struct{})
}

func (m *MeshAgent) runStreaming() {
	ticker := time.NewTicker(3 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			return
		case <-ticker.C:
			if m.IsMaster && len(m.Songs) > 0 {
				m.Mutex.Lock()
				// Select random song
				idx := time.Now().UnixNano() % int64(len(m.Songs))
				m.CurrentSong = m.Songs[idx]
				log.Printf("📻 Streaming: %s", m.CurrentSong)
				m.Mutex.Unlock()
				
				// Stream to all peers
				m.streamToPeers(m.CurrentSong)
			}
		}
	}
}

func (m *MeshAgent) streamToPeers(song string) {
	m.Mutex.RLock()
	defer m.Mutex.RUnlock()

	for _, peer := range m.Peers {
		url := fmt.Sprintf("http://%s:8080/set-song", peer.IP)
		reqBody := strings.NewReader(fmt.Sprintf(`{"song":"%s"}`, song))
		http.Post(url, "application/json", reqBody)
	}
}

func (m *MeshAgent) printStatus() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-m.ctx.Done():
			return
		case <-ticker.C:
			m.Mutex.RLock()
			log.Printf("📊 Status: ID=%s Master=%v Peers=%d Songs=%d Song=%s",
				m.ID[:min(15, len(m.ID))],
				m.IsMaster,
				len(m.Peers),
				len(m.Songs),
				m.CurrentSong,
			)
			m.Mutex.RUnlock()
		}
	}
}

// Helper functions
func getNodeID() string {
	hostname, _ := os.Hostname()
	mac := getMACAddress()
	return fmt.Sprintf("%s-%s", hostname, mac)
}

func getMACAddress() string {
	ifaces, _ := net.Interfaces()
	for _, iface := range ifaces {
		if iface.Flags&net.FlagLoopback == 0 && iface.HardwareAddr != nil {
			return iface.HardwareAddr.String()
		}
	}
	return "00:00:00:00:00:00"
}

func getLocalIP() string {
	conn, _ := net.Dial("udp", "8.8.8.8:80")
	if conn != nil {
		defer conn.Close()
		return conn.LocalAddr().(*net.UDPAddr).IP.String()
	}
	return "127.0.0.1"
}

func loadNodeSongs() []string {
	// Load songs from /songs directory
	files, _ := os.ReadDir("/songs")
	songs := make([]string, 0)
	for _, f := range files {
		if !f.IsDir() && (hasExt(f.Name(), ".wav") || hasExt(f.Name(), ".mp3") || hasExt(f.Name(), ".ogg")) {
			songs = append(songs, f.Name())
		}
	}
	// If no songs in /songs, try node-specific directory
	if len(songs) == 0 {
		hostname, _ := os.Hostname()
		nodeSongsDir := fmt.Sprintf("/songs/node_%s", hostname)
		if files, err := os.ReadDir(nodeSongsDir); err == nil {
			for _, f := range files {
				if !f.IsDir() && (hasExt(f.Name(), ".wav") || hasExt(f.Name(), ".mp3")) {
					songs = append(songs, f.Name())
				}
			}
		}
	}
	return songs
}

func hasExt(name, ext string) bool {
	return len(name) > len(ext) && name[len(name)-len(ext):] == ext
}

func getTxRate() float64 {
	// Simulate TX rate based on time
	return 54.0 + float64(time.Now().Unix()%20)
}

func getSignalStrength() int {
	// Simulate signal strength
	return -50 + int(time.Now().Unix()%20)
}

func getModulation() string {
	mods := []string{"QPSK", "16-QAM", "64-QAM", "256-QAM"}
	return mods[int(time.Now().Unix())%len(mods)]
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}