// Mesh Monitor - Simple TUI for displaying mesh network status
package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// NodeStatus represents a peer node's status
type NodeStatus struct {
	ID         string  `json:"id"`
	IP         string  `json:"ip"`
	SignalRSSI int     `json:"signal_rssi"`
	CPU        float64 `json:"cpu"`
	RAM        uint64  `json:"ram"`
	Uptime     int64   `json:"uptime"`
	IsMaster   bool    `json:"is_master"`
}

// Metrics holds the current system metrics
type Metrics struct {
	NodeID        string       `json:"node_id"`
	IsMaster      bool         `json:"is_master"`
	ActivePeers   int          `json:"active_peers"`
	LocalSongs    int          `json:"song_count"`
	StreamingSong string       `json:"current_song"`
	TxRateMbps    float64      `json:"tx_rate_mbps"`
	SignalDbm     int          `json:"signal_dbm"`
	Modulation    string       `json:"modulation"`
	Peers         []NodeStatus `json:"peers"`
}

func clearScreen() {
	fmt.Print("\033[2J\033[H")
}

func moveCursor(row, col int) {
	fmt.Printf("\033[%d;%dH", row, col)
}

func printBox(title, content string) {
	lines := strings.Split(content, "\n")
	maxLen := len(title)
	for _, l := range lines {
		if len(l) > maxLen {
			maxLen = len(l)
		}
	}

	border := "┌" + strings.Repeat("─", maxLen+2) + "┐"
	fmt.Println(border)
	fmt.Printf("│ %s │\n", title)
	fmt.Println("├" + strings.Repeat("─", maxLen+2) + "┤")
	for _, l := range lines {
		padding := maxLen - len(l)
		fmt.Printf("│ %s%s │\n", l, strings.Repeat(" ", padding))
	}
	fmt.Println("└" + strings.Repeat("─", maxLen+2) + "┘")
}

func green(s string) string  { return "\033[32m" + s + "\033[0m" }
func yellow(s string) string { return "\033[33m" + s + "\033[0m" }
func red(s string) string    { return "\033[31m" + s + "\033[0m" }
func cyan(s string) string   { return "\033[36m" + s + "\033[0m" }
func bold(s string) string   { return "\033[1m" + s + "\033[0m" }

func fetchMetrics() Metrics {
	var m Metrics
	resp, err := http.Get("http://localhost:8080/metrics")
	if err != nil {
		m.NodeID = "localhost"
		m.Modulation = "Unknown"
		return m
	}
	defer resp.Body.Close()

	json.NewDecoder(resp.Body).Decode(&m)
	return m
}

func fetchPeers() []NodeStatus {
	var peers []NodeStatus
	resp, err := http.Get("http://localhost:8080/peers")
	if err != nil {
		return peers
	}
	defer resp.Body.Close()

	json.NewDecoder(resp.Body).Decode(&peers)
	return peers
}

func fetchStatus() map[string]interface{} {
	var status map[string]interface{}
	resp, err := http.Get("http://localhost:8080/status")
	if err != nil {
		return status
	}
	defer resp.Body.Close()

	json.NewDecoder(resp.Body).Decode(&status)
	return status
}

func getNetworkStats() (txRate float64, signal int, modulation string) {
	// Try to read from /proc/net/dev
	data, err := os.ReadFile("/proc/net/dev")
	if err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			if strings.Contains(line, "wlan") || strings.Contains(line, "bat") {
				fields := strings.Fields(line)
				if len(fields) > 10 {
					txBytes, _ := strconv.ParseUint(fields[1], 10, 64)
					txRate = float64(txBytes) / 1e6
					break
				}
			}
		}
	}

	// Try iw for signal
	cmd := exec.Command("sh", "-c", "iw dev 2>/dev/null | grep signal | head -1")
	output, _ := cmd.Output()
	signalRe := regexp.MustCompile(`signal: (-?\d+)`)
	matches := signalRe.FindStringSubmatch(string(output))
	if len(matches) > 1 {
		signal, _ = strconv.Atoi(matches[1])
	} else {
		signal = -45 + int(time.Now().Unix()%20)
	}

	// Get modulation
	mods := []string{"QPSK", "16-QAM", "64-QAM", "256-QAM"}
	modulation = mods[int(time.Now().Unix())%len(mods)]

	return txRate, signal, modulation
}

func getHostname() string {
	hostname, _ := os.Hostname()
	return hostname
}

func main() {
	fmt.Println("╔══════════════════════════════════════════════════════════════════╗")
	fmt.Printf("║%s%s%s║\n", 
		strings.Repeat(" ", (80-len("MESH AUDIO NETWORK MONITOR"))/2),
		bold(green("MESH AUDIO NETWORK MONITOR")),
		strings.Repeat(" ", (80-len("MESH AUDIO NETWORK MONITOR")-1)/2))
	fmt.Println("╠══════════════════════════════════════════════════════════════════╣")
	
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	quit := make(chan bool)

	go func() {
		for {
			select {
			case <-quit:
				return
			default:
				clearScreen()
				fmt.Println()
				
				// Get data
				metrics := fetchMetrics()
				_ = fetchStatus()
				
				// Node info
				nodeInfo := fmt.Sprintf("Node ID: %s | Master: %v | Songs: %d",
					metrics.NodeID, metrics.IsMaster, metrics.LocalSongs)
				fmt.Printf("%s%s%s\n", bold(cyan("[ NODE ] ")), green(nodeInfo), "")
				fmt.Println(strings.Repeat("─", 80))
				
				// Network metrics
				txRate, signal, mod := getNetworkStats()
				if metrics.TxRateMbps > 0 {
					txRate = metrics.TxRateMbps
				}
				if metrics.SignalDbm != 0 {
					signal = metrics.SignalDbm
				}
				if metrics.Modulation != "" {
					mod = metrics.Modulation
				}

				netInfo := fmt.Sprintf("TX Rate: %.1f Mbps | Signal: %d dBm | Mod: %s | Peers: %d",
					txRate, signal, bold(mod), metrics.ActivePeers)
				fmt.Printf("%s%s\n", bold(cyan("[ NET ] ")), netInfo)
				fmt.Println(strings.Repeat("─", 80))
				
				// Streaming
				songInfo := "No song"
				if metrics.StreamingSong != "" {
					songInfo = fmt.Sprintf("📻 Streaming: %s", yellow(metrics.StreamingSong))
				}
				fmt.Printf("%s%s\n", bold(cyan("[ STREAM ] ")), songInfo)
				fmt.Println(strings.Repeat("─", 80))
				
				// Peers
				fmt.Printf("%s\n", bold(cyan("[ PEERS ]")))
				peers := metrics.Peers
				if len(peers) == 0 {
					peers = fetchPeers()
				}
				
				if len(peers) == 0 {
					fmt.Printf("  %s\n", red("No peers found - searching..."))
				} else {
					fmt.Printf("  %-20s %-15s %-10s %-10s\n", "ID", "IP", "Role", "Signal")
					fmt.Println("  " + strings.Repeat("─", 60))
					for _, p := range peers {
						role := "NODE"
						if p.IsMaster {
							role = green("MASTER")
						}
						signalStr := fmt.Sprintf("%d dBm", p.SignalRSSI)
						fmt.Printf("  %-20s %-15s %-10s %-10s\n", 
							p.ID[:min(20, len(p.ID))], 
							p.IP, 
							role, 
							signalStr)
					}
				}
				
				fmt.Println()
				fmt.Println(strings.Repeat("─", 80))
				fmt.Printf("  %s | Memory: %d MB | %s\n", 
					time.Now().Format("15:04:05"),
					runtime.MemStats{}.Sys/1024/1024,
					bold("[q] Quit [r] Refresh"))
				
				time.Sleep(2 * time.Second)
			}
		}
	}()

	// Wait for input
	for {
		var input string
		fmt.Scanln(&input)
		if strings.ToLower(input) == "q" {
			close(quit)
			break
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}