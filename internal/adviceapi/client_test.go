package adviceapi

import (
	"context"
	"crypto/tls"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func testClient(server *httptest.Server) *Client {
	c := New(time.Second)
	c.Endpoint = strings.Replace(server.URL, "http://", "https://", 1)
	c.HTTPClient.Transport = &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}} // test server only
	c.Now = func() time.Time { return time.Date(2026, 11, 12, 11, 30, 0, 0, time.UTC) }
	return c
}

func TestFetchPreservesUnicodeAndIgnoresUnknown(t *testing.T) {
	s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"id":19557,"text":"Двигайся дальше, ёпта!","sound":"","future":true}`))
	}))
	defer s.Close()
	got, err := testClient(s).Fetch(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if got.Text != "Двигайся дальше, ёпта!" || got.FetchedAt != "2026-11-12T11:30:00Z" {
		t.Fatalf("unexpected: %#v", got)
	}
}

func TestFetchRejectsInvalidResponses(t *testing.T) {
	tests := []struct {
		name, body string
		status     int
		code       string
	}{
		{"empty", `{"id":1,"text":" "}`, 200, "empty_text"},
		{"id", `{"id":0,"text":"x"}`, 200, "invalid_id"},
		{"malformed", `{`, 200, "invalid_json"},
		{"trailing", `{"id":1,"text":"x"}{}`, 200, "invalid_json"},
		{"status", `{}`, 503, "http_status"},
		{"large", `{"id":1,"text":"` + strings.Repeat("x", MaxBodyBytes) + `"}`, 200, "response_too_large"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(tt.status)
				_, _ = w.Write([]byte(tt.body))
			}))
			defer s.Close()
			_, err := testClient(s).Fetch(context.Background())
			if typed, ok := err.(*Error); !ok || typed.Code != tt.code {
				t.Fatalf("got %T %v", err, err)
			}
		})
	}
}

func TestNoRetryOrRedirect(t *testing.T) {
	var calls atomic.Int32
	s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls.Add(1)
		http.Redirect(w, nil, "https://example.com", http.StatusFound)
	}))
	defer s.Close()
	_, _ = testClient(s).Fetch(context.Background())
	if calls.Load() != 1 {
		t.Fatalf("requests = %d", calls.Load())
	}
}

func TestTimeout(t *testing.T) {
	s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		time.Sleep(100 * time.Millisecond)
		_, _ = w.Write([]byte(`{"id":1,"text":"x"}`))
	}))
	defer s.Close()
	c := testClient(s)
	c.HTTPClient.Timeout = 10 * time.Millisecond
	_, err := c.Fetch(context.Background())
	if typed, ok := err.(*Error); !ok || typed.Code != "timeout" {
		t.Fatalf("got %T %v", err, err)
	}
}
