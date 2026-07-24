package handlers

import (
	"encoding/json"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/executt/govaishield/api-gateway/internal/config"
)

// Version é injetado no build via -ldflags.
var Version = "dev"

func Health() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}

// Ready checa APENAS as dependências listadas em READY_CHECKS (default: postgres).
// Deps não listadas não aparecem no resultado (não contam como "down").
// Assim o serviço fica Ready no cluster mesmo antes de Kafka/Redis existirem.
func Ready(cfg config.Config) http.HandlerFunc {
	addrs := map[string]string{
		"postgres": cfg.PGHost + ":" + cfg.PGPort,
		"kafka":    first(cfg.Kafka),
		"redis":    cfg.Redis,
	}
	return func(w http.ResponseWriter, r *http.Request) {
		result := map[string]string{}
		allOK := true
		for _, name := range cfg.ReadyChecks {
			addr := addrs[name]
			if addr == "" || addr == ":" || strings.HasPrefix(addr, ":") {
				result[name] = "not_configured"
				continue
			}
			c, err := net.DialTimeout("tcp", addr, 1500*time.Millisecond)
			if err != nil {
				result[name] = "down"
				allOK = false
			} else {
				_ = c.Close()
				result[name] = "up"
			}
		}
		status := http.StatusOK
		if !allOK {
			status = http.StatusServiceUnavailable
		}
		writeJSON(w, status, map[string]any{"status": boolOK(allOK), "checks": cfg.ReadyChecks, "deps": result})
	}
}

func Startup() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "started"})
	}
}

func VersionH() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"version": Version, "service": "api-gateway"})
	}
}

func first(s []string) string {
	if len(s) == 0 {
		return ""
	}
	return s[0]
}
func boolOK(b bool) string {
	if b {
		return "ok"
	}
	return "degraded"
}
func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
