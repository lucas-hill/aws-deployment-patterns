package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"sync"
	"time"
)

// Item is our in-memory data model. No database yet — we'll add RDS in Phase 2.
type Item struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

// store is a thread-safe in-memory store. Mutex because multiple HTTP requests
// can hit this concurrently — Go's net/http handles each request in a goroutine.
type store struct {
	mu     sync.RWMutex
	items  []Item
	nextID int
}

func newStore() *store {
	return &store{nextID: 1}
}

func (s *store) list() []Item {
	s.mu.RLock()
	defer s.mu.RUnlock()
	// Return a copy so callers can't mutate our internal slice.
	out := make([]Item, len(s.items))
	copy(out, s.items)
	return out
}

func (s *store) add(name string) Item {
	s.mu.Lock()
	defer s.mu.Unlock()
	item := Item{
		ID:        s.nextID,
		Name:      name,
		CreatedAt: time.Now().UTC(),
	}
	s.items = append(s.items, item)
	s.nextID++
	return item
}

// envOrDefault reads an env var or returns a fallback. We use this so the app
// behaves correctly both locally and in containers where env vars come from
// docker-compose, ECS task definitions, or EKS ConfigMaps.
func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	// Config from env vars — the 12-factor app pattern.
	port := envOrDefault("PORT", "8080")
	appEnv := envOrDefault("APP_ENV", "local")
	logLevel := envOrDefault("LOG_LEVEL", "info")

	// Structured JSON logging to stdout. CloudWatch picks this up automatically
	// when the container runs on ECS/EKS — no extra agent needed.
	var level slog.Level
	switch logLevel {
	case "debug":
		level = slog.LevelDebug
	case "warn":
		level = slog.LevelWarn
	case "error":
		level = slog.LevelError
	default:
		level = slog.LevelInfo
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level}))
	slog.SetDefault(logger)

	s := newStore()
	mux := http.NewServeMux()

	// GET / — root, just confirms the app is alive and shows env info.
	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{
			"message": "cloud-deploy-practice API",
			"env":     appEnv,
		})
	})

	// GET /health — health check endpoint. ALB, ECS, and EKS all poll this
	// to decide whether to send traffic. Keep it cheap and dependency-free.
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// GET /items — list all items.
	mux.HandleFunc("GET /items", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, s.list())
	})

	// POST /items — create a new item. Expects {"name": "..."} JSON body.
	mux.HandleFunc("POST /items", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Name string `json:"name"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
			return
		}
		if body.Name == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name is required"})
			return
		}
		item := s.add(body.Name)
		slog.Info("item created", "id", item.ID, "name", item.Name)
		writeJSON(w, http.StatusCreated, item)
	})

	// Wrap the mux with a logging middleware so we get a log line per request.
	handler := logRequests(mux)

	addr := ":" + port
	slog.Info("server starting", "addr", addr, "env", appEnv)

	srv := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	if err := srv.ListenAndServe(); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("failed to write JSON response", "error", err)
	}
}

// logRequests is a tiny middleware that logs every incoming request.
// In Laravel terms: think of this as a global HTTP middleware in Kernel.php.
func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		// Wrap the ResponseWriter so we can capture the status code.
		rw := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rw, r)
		slog.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rw.status,
			"duration_ms", time.Since(start).Milliseconds(),
			"remote_addr", r.RemoteAddr,
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}
