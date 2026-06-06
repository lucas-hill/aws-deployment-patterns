package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// newTestServer spins up an httptest.Server backed by the real router and a
// fresh in-memory store. Returns the server and a cleanup the caller defers.
// Each test gets its own store, so tests stay independent and can run in parallel.
func newTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(newRouter(newStore(), "test"))
	t.Cleanup(srv.Close)
	return srv
}

func TestHealth(t *testing.T) {
	srv := newTestServer(t)

	resp, err := http.Get(srv.URL + "/health")
	if err != nil {
		t.Fatalf("GET /health: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf(`status field = %q, want "ok"`, body["status"])
	}
}

func TestRoot(t *testing.T) {
	srv := newTestServer(t)

	resp, err := http.Get(srv.URL + "/")
	if err != nil {
		t.Fatalf("GET /: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	// We passed "test" as appEnv into newRouter — confirm it flows through.
	if body["env"] != "test" {
		t.Errorf(`env field = %q, want "test"`, body["env"])
	}
}

func TestItemsEmptyOnStartup(t *testing.T) {
	srv := newTestServer(t)

	resp, err := http.Get(srv.URL + "/items")
	if err != nil {
		t.Fatalf("GET /items: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var items []Item
	if err := json.NewDecoder(resp.Body).Decode(&items); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(items) != 0 {
		t.Errorf("got %d items, want 0", len(items))
	}
}

func TestCreateItem(t *testing.T) {
	srv := newTestServer(t)

	resp, err := http.Post(srv.URL+"/items", "application/json",
		strings.NewReader(`{"name":"widget"}`))
	if err != nil {
		t.Fatalf("POST /items: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}

	var item Item
	if err := json.NewDecoder(resp.Body).Decode(&item); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if item.Name != "widget" {
		t.Errorf("name = %q, want %q", item.Name, "widget")
	}
	if item.ID != 1 {
		t.Errorf("id = %d, want 1 (first item)", item.ID)
	}
	if item.CreatedAt.IsZero() {
		t.Error("created_at is zero, want a timestamp")
	}
}

func TestCreateItemValidation(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		wantStatus int
	}{
		{name: "missing name", body: `{}`, wantStatus: http.StatusBadRequest},
		{name: "empty name", body: `{"name":""}`, wantStatus: http.StatusBadRequest},
		{name: "invalid json", body: `{not json`, wantStatus: http.StatusBadRequest},
		{name: "valid", body: `{"name":"ok"}`, wantStatus: http.StatusCreated},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			srv := newTestServer(t)

			resp, err := http.Post(srv.URL+"/items", "application/json",
				strings.NewReader(tc.body))
			if err != nil {
				t.Fatalf("POST /items: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != tc.wantStatus {
				t.Errorf("status = %d, want %d", resp.StatusCode, tc.wantStatus)
			}
		})
	}
}

// TestCreateThenList confirms a created item shows up in the subsequent list,
// exercising the round-trip through the shared store.
func TestCreateThenList(t *testing.T) {
	srv := newTestServer(t)

	for _, name := range []string{"alpha", "beta"} {
		resp, err := http.Post(srv.URL+"/items", "application/json",
			strings.NewReader(`{"name":"`+name+`"}`))
		if err != nil {
			t.Fatalf("POST /items: %v", err)
		}
		resp.Body.Close()
	}

	resp, err := http.Get(srv.URL + "/items")
	if err != nil {
		t.Fatalf("GET /items: %v", err)
	}
	defer resp.Body.Close()

	var items []Item
	if err := json.NewDecoder(resp.Body).Decode(&items); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("got %d items, want 2", len(items))
	}
	if items[0].Name != "alpha" || items[1].Name != "beta" {
		t.Errorf("items = [%q, %q], want [alpha, beta]", items[0].Name, items[1].Name)
	}
}

// TestStoreConcurrency hammers the store from many goroutines. Run with
// `go test -race` and the data race detector will fail the build if the
// mutex in store ever stops protecting the slice. This is the test that
// justifies the RWMutex in main.go.
func TestStoreConcurrency(t *testing.T) {
	s := newStore()
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			s.add("concurrent")
			_ = s.list()
		}()
	}
	wg.Wait()

	if got := len(s.list()); got != goroutines {
		t.Errorf("got %d items after %d concurrent adds, want %d",
			got, goroutines, goroutines)
	}
}

// Ensure newRouter handles a JSON body read from a bytes.Buffer the same way —
// guards against any future change that assumes a particular Body type.
func TestCreateItemWithBuffer(t *testing.T) {
	srv := newTestServer(t)

	payload, _ := json.Marshal(map[string]string{"name": "from-buffer"})
	resp, err := http.Post(srv.URL+"/items", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("POST /items: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusCreated)
	}
}
