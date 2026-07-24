package handlers

import (
	"encoding/json"
	"net"
	"net/http"
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

// Ready checa dependências com TCP dial (zero dependência de driver).
func Ready(cfg config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		checks := map[string]string{
			"postgres": cfg.PGHost + ":" + cfg.PGPort,
			"kafka":    first(cfg.Kafka),
			"redis":    cfg.Redis,
		}
		allOK := true
		result := map[string]string{}
		for name, addr := range checks {
			if addr == "" || addr == ":" {
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
		writeJSON(w, status, map[string]any{"status": boolOK(allOK), "deps": result})
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
