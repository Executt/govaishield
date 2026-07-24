package config

import (
	"os"
	"strings"
)

type Config struct {
	AppEnv      string
	Port        string
	PGHost      string
	PGPort      string
	Kafka       []string
	Redis       string
	ReadyChecks []string // dependências que o /health/ready efetivamente checa
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func csv(k, def string) []string {
	parts := strings.Split(get(k, def), ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func Load() Config {
	return Config{
		AppEnv:      get("APP_ENV", "development"),
		Port:        get("APP_PORT", "8080"),
		PGHost:      get("POSTGRES_HOST", "localhost"),
		PGPort:      get("POSTGRES_PORT", "5432"),
		Kafka:       strings.Split(get("KAFKA_BROKERS", ""), ","),
		Redis:       get("REDIS_HOST", "") + ":" + get("REDIS_PORT", "6379"),
		ReadyChecks: csv("READY_CHECKS", "postgres"),
	}
}
