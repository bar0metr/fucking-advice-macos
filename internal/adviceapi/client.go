package adviceapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
	"unicode"
)

const (
	Endpoint       = "https://fucking-great-advice.ru/api/random"
	MaxBodyBytes   = 64 << 10
	DefaultTimeout = 8 * time.Second
)

type Advice struct {
	ID        int64  `json:"id"`
	Text      string `json:"text"`
	Sound     string `json:"sound,omitempty"`
	FetchedAt string `json:"fetchedAt"`
}

type apiResponse struct {
	ID    int64  `json:"id"`
	Text  string `json:"text"`
	Sound string `json:"sound"`
}

type Error struct {
	Code   string `json:"code"`
	Status int    `json:"status,omitempty"`
	Detail string `json:"detail,omitempty"`
}

func (e *Error) Error() string {
	if e.Detail == "" {
		return e.Code
	}
	return e.Code + ": " + e.Detail
}

type Client struct {
	HTTPClient *http.Client
	Endpoint   string
	Now        func() time.Time
}

func New(timeout time.Duration) *Client {
	return &Client{
		HTTPClient: &http.Client{
			Timeout:       timeout,
			CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse },
		},
		Endpoint: Endpoint,
		Now:      time.Now,
	}
}

func (c *Client) Fetch(ctx context.Context) (Advice, error) {
	u, err := url.Parse(c.Endpoint)
	if err != nil || u.Scheme != "https" {
		return Advice{}, &Error{Code: "invalid_endpoint", Detail: "HTTPS is required"}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return Advice{}, &Error{Code: "request_failed", Detail: err.Error()}
	}
	req.Header.Set("Accept", "application/json")
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		code := "network_error"
		if errors.Is(err, context.DeadlineExceeded) || errors.Is(ctx.Err(), context.DeadlineExceeded) {
			code = "timeout"
		}
		return Advice{}, &Error{Code: code, Detail: safeDetail(err)}
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return Advice{}, &Error{Code: "http_status", Status: resp.StatusCode}
	}
	limited := io.LimitReader(resp.Body, MaxBodyBytes+1)
	body, err := io.ReadAll(limited)
	if err != nil {
		return Advice{}, &Error{Code: "read_error", Detail: safeDetail(err)}
	}
	if len(body) > MaxBodyBytes {
		return Advice{}, &Error{Code: "response_too_large"}
	}
	var decoded apiResponse
	dec := json.NewDecoder(strings.NewReader(string(body)))
	if err := dec.Decode(&decoded); err != nil {
		return Advice{}, &Error{Code: "invalid_json", Detail: safeDetail(err)}
	}
	if err := ensureSingleJSON(dec); err != nil {
		return Advice{}, &Error{Code: "invalid_json", Detail: err.Error()}
	}
	text := normalize(decoded.Text)
	if decoded.ID <= 0 {
		return Advice{}, &Error{Code: "invalid_id"}
	}
	if strings.TrimSpace(text) == "" {
		return Advice{}, &Error{Code: "empty_text"}
	}
	return Advice{ID: decoded.ID, Text: text, Sound: decoded.Sound, FetchedAt: c.Now().UTC().Format(time.RFC3339)}, nil
}

func ensureSingleJSON(dec *json.Decoder) error {
	var extra any
	if err := dec.Decode(&extra); !errors.Is(err, io.EOF) {
		return fmt.Errorf("trailing JSON data")
	}
	return nil
}

func normalize(s string) string {
	return strings.Map(func(r rune) rune {
		if r == '\n' || r == '\t' {
			return r
		}
		if unicode.IsControl(r) {
			return -1
		}
		return r
	}, s)
}

func safeDetail(err error) string {
	if err == nil {
		return ""
	}
	text := err.Error()
	if len(text) > 240 {
		return text[:240]
	}
	return text
}
