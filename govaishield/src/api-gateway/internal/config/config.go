package config

import (
	"os"
	"strings"
)

type Config struct {
	AppEnv string
	Port   string
	PGHost string
	PGPort string
	Kafka  []string
	Redis  string
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func Load() Config {
	return Config{
		AppEnv: get("APP_ENV", "development"),
		Port:   get("APP_PORT", "8080"),
		PGHost: get("POSTGRES_HOST", "localhost"),
		PGPort: get("POSTGRES_PORT", "5432"),
		Kafka:  strings.Split(get("KAFKA_BROKERS", "localhost:9092"), ","),
		Redis:  get("REDIS_HOST", "localhost") + ":" + get("REDIS_PORT", "6379"),
	}
}
