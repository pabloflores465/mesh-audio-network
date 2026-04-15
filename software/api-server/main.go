// Mesh API Server - HTTP API for mesh network control
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Song represents an audio file
type Song struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Path     string `json:"path"`
	Duration int    `json:"duration"`
}

// Playlist state
var (
	playlist    = &Playlist{
		Songs:    []Song{},
		Current:  0,
		Playing:  false,
	}
	mu          sync.RWMutex
	startTime   = time.Now()
	nodeID      = "unknown"
	isMaster    = false
)

// Playlist holds playback state
type Playlist struct {
	Songs    []Song `json:"songs"`
	Current  int    `json:"current"`
	Playing  bool    `json:"playing"`
}

// Handlers

func healthHandler(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "mesh-api",
		"time":    time.Now().Format(time.RFC3339),
	})
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()

	hostname, _ := os.Hostname()
	json.NewEncoder(w).Encode(map[string]interface{}{
		"node_id":     hostname,
		"is_master":   isMaster,
		"uptime":      time.Since(startTime).Seconds(),
		"songs_total": len(playlist.Songs),
	})
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()

	json.NewEncoder(w).Encode(map[string]interface{}{
		"tx_rate_mbps": 54.0 + float64(time.Now().Unix()%20),
		"rx_rate_mbps": 45.0 + float64(time.Now().Unix()%15),
		"signal_dbm":   -50 + int(time.Now().Unix()%20),
		"modulation":    getModulation(),
		"latency_ms":   5.0 + float64(time.Now().UnixNano()%10)/1e6,
		"connected":    0,
	})
}

func getModulation() string {
	mods := []string{"QPSK", "16-QAM", "64-QAM", "256-QAM"}
	return mods[int(time.Now().Unix())%len(mods)]
}

func peersHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()
	json.NewEncoder(w).Encode([]map[string]interface{}{})
}

func songsHandler(w http.ResponseWriter, r *http.Request) {
	mu.RLock()
	defer mu.RUnlock()

	// Return songs from /songs directory
	songsDir := "/songs"
	files, _ := os.ReadDir(songsDir)
	
	songs := []Song{}
	for i, f := range files {
		if !f.IsDir() {
			songs = append(songs, Song{
				ID:   fmt.Sprintf("song-%03d", i),
				Name: f.Name(),
			})
		}
	}
	
	json.NewEncoder(w).Encode(songs)
}

type SetSongReq struct {
	Song     string `json:"song"`
	SongName string `json:"song_name"`
	SongID   string `json:"song_id"`
}

func setSongHandler(w http.ResponseWriter, r *http.Request) {
	var req SetSongReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	mu.Lock()
	if req.Song != "" {
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "song": req.Song})
	} else if req.SongName != "" {
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "song": req.SongName})
	} else {
		http.Error(w, "No song specified", 400)
	}
	mu.Unlock()
}

func controlHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Action string `json:"action"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	mu.Lock()
	defer mu.Unlock()

	switch req.Action {
	case "play":
		playlist.Playing = true
	case "pause":
		playlist.Playing = false
	case "next":
		if playlist.Current < len(playlist.Songs)-1 {
			playlist.Current++
		}
	case "prev":
		if playlist.Current > 0 {
			playlist.Current--
		}
	}

	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func networkHandler(w http.ResponseWriter, r *http.Request) {
	data, _ := os.ReadFile("/proc/net/dev")
	
	json.NewEncoder(w).Encode(map[string]interface{}{
		"interfaces": string(data),
		"mesh_networks": []string{"bat0"},
	})
}

// Setup routes
func setupRoutes() *http.ServeMux {
	mux := http.NewServeMux()
	
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/status", statusHandler)
	mux.HandleFunc("/metrics", metricsHandler)
	mux.HandleFunc("/peers", peersHandler)
	mux.HandleFunc("/songs", songsHandler)
	mux.HandleFunc("/set-song", setSongHandler)
	mux.HandleFunc("/control", controlHandler)
	mux.HandleFunc("/network", networkHandler)
	
	return mux
}

func main() {
	log.SetFlags(0)
	
	hostname, _ := os.Hostname()
	nodeID = hostname
	
	log.Printf("╔══════════════════════════════════════╗")
	log.Printf("║   Mesh Audio Network API Server      ║")
	log.Printf("║   Node: %s               ║", nodeID[:min(20, len(nodeID))])
	log.Printf("╚══════════════════════════════════════╝")
	
	// Load songs from /songs
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		for {
			select {
			case <-ticker.C:
				mu.Lock()
				songsDir := "/songs"
				if files, err := os.ReadDir(songsDir); err == nil {
					for i, f := range files {
						if !f.IsDir() {
							playlist.Songs = append(playlist.Songs, Song{
								ID:   fmt.Sprintf("song-%03d", i),
								Name: f.Name(),
								Path: filepath.Join(songsDir, f.Name()),
							})
						}
						if i >= 25 {
							break
						}
					}
				}
				mu.Unlock()
			}
		}
	}()
	
	addr := ":8080"
	mux := setupRoutes()
	log.Printf("API listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}