package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/bar0metr/fucking-advice-macos/internal/adviceapi"
	"github.com/bar0metr/fucking-advice-macos/internal/fetchprotocol"
)

func main() { os.Exit(run(os.Args[1:])) }

func run(args []string) int {
	if len(args) == 0 || args[0] != "fetch" {
		fmt.Fprintln(os.Stderr, `{"error":{"code":"usage","detail":"usage: advice-fetcher fetch --timeout=8s"}}`)
		return 2
	}
	flags := flag.NewFlagSet("fetch", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	timeout := flags.Duration("timeout", adviceapi.DefaultTimeout, "request timeout")
	if err := flags.Parse(args[1:]); err != nil || *timeout <= 0 || flags.NArg() != 0 {
		fmt.Fprintln(os.Stderr, `{"error":{"code":"usage","detail":"usage: advice-fetcher fetch --timeout=8s"}}`)
		return 2
	}
	ctx, cancel := context.WithTimeout(context.Background(), *timeout+time.Second)
	defer cancel()
	result, err := adviceapi.New(*timeout).Fetch(ctx)
	if err != nil {
		_ = fetchprotocol.WriteError(os.Stderr, err)
		return 1
	}
	if err := fetchprotocol.WriteSuccess(os.Stdout, result); err != nil {
		_ = fetchprotocol.WriteError(os.Stderr, err)
		return 1
	}
	return 0
}
