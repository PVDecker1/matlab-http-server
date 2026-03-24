package main

import (
	"bufio"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

type Request struct {
	ID      string            `json:"id"`
	Method  string            `json:"method"`
	Path    string            `json:"path"`
	Query   string            `json:"query"`
	Headers map[string]string `json:"headers"`
	Body    string            `json:"body"`
}

type Response struct {
	ID      string            `json:"id"`
	Status  int               `json:"status"`
	Headers map[string]string `json:"headers"`
	Body    string            `json:"body"` // Base64 encoded for binary safety
}

var pendingRequests sync.Map // map[string]chan Response

func uuid() string {
	b := make([]byte, 16)
	_, err := rand.Read(b)
	if err != nil {
		log.Fatal(err)
	}
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func main() {
	port := flag.Int("port", 8080, "HTTP port to listen on")
	flag.Parse()

	// Start stdin reader
	go readStdin()

	http.HandleFunc("/", handleHTTP)

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Go sidecar listening on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}

func handleHTTP(w http.ResponseWriter, r *http.Request) {
	id := uuid()
	
	body, _ := io.ReadAll(r.Body)
	
	headers := make(map[string]string)
	for k, v := range r.Header {
		headers[k] = v[0]
	}

	req := Request{
		ID:      id,
		Method:  r.Method,
		Path:    r.URL.Path,
		Query:   r.URL.RawQuery,
		Headers: headers,
		Body:    string(body),
	}

	// Track this request
	resChan := make(chan Response, 1)
	pendingRequests.Store(id, resChan)
	defer pendingRequests.Delete(id)

	// Send to MATLAB stdout
	data, _ := json.Marshal(req)
	fmt.Println(string(data))

	// Wait for MATLAB response with 30s timeout
	select {
	case res := <-resChan:
		for k, v := range res.Headers {
			w.Header().Set(k, v)
		}
		w.WriteHeader(res.Status)
		
		bodyBytes, err := base64.StdEncoding.DecodeString(res.Body)
		if err != nil {
			w.Write([]byte(res.Body))
		} else {
			w.Write(bodyBytes)
		}
	case <-time.After(30 * time.Second):
		w.WriteHeader(http.StatusGatewayTimeout)
		fmt.Fprint(w, "MATLAB response timeout")
	}
}

func readStdin() {
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := scanner.Text()
		var res Response
		if err := json.Unmarshal([]byte(line), &res); err != nil {
			log.Printf("Error parsing JSON from MATLAB: %v", err)
			continue
		}

		if val, ok := pendingRequests.Load(res.ID); ok {
			resChan := val.(chan Response)
			resChan <- res
		}
	}
	if err := scanner.Err(); err != nil {
		log.Printf("Stdin error: %v", err)
	}
	os.Exit(0) // Exit if stdin closed
}
