package fetchprotocol

import (
	"encoding/json"
	"fmt"
	"io"

	"github.com/bar0metr/fucking-advice-macos/internal/adviceapi"
)

type Failure struct {
	Error ErrorBody `json:"error"`
}
type ErrorBody struct {
	Code   string `json:"code"`
	Status int    `json:"status,omitempty"`
	Detail string `json:"detail,omitempty"`
}

func WriteSuccess(w io.Writer, advice adviceapi.Advice) error {
	return json.NewEncoder(w).Encode(advice)
}

func WriteError(w io.Writer, err error) error {
	body := ErrorBody{Code: "internal_error"}
	if typed, ok := err.(*adviceapi.Error); ok {
		body = ErrorBody{Code: typed.Code, Status: typed.Status, Detail: typed.Detail}
	}
	if encodeErr := json.NewEncoder(w).Encode(Failure{Error: body}); encodeErr != nil {
		return fmt.Errorf("encode error: %w", encodeErr)
	}
	return nil
}
