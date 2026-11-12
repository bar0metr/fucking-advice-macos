package fetchprotocol

import (
	"bytes"
	"encoding/json"
	"github.com/bar0metr/fucking-advice-macos/internal/adviceapi"
	"testing"
)

func TestOutputIsSingleJSONLine(t *testing.T) {
	var out bytes.Buffer
	if err := WriteSuccess(&out, adviceapi.Advice{ID: 1, Text: "ё", FetchedAt: "now"}); err != nil {
		t.Fatal(err)
	}
	if out.Bytes()[len(out.Bytes())-1] != '\n' {
		t.Fatal("missing newline")
	}
	var value map[string]any
	if err := json.Unmarshal(out.Bytes(), &value); err != nil {
		t.Fatal(err)
	}
}
