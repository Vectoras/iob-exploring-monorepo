package middleware

import (
	"log"
	"net/http"
	"time"
)

// --- interceptor

type responseRecorder struct {
	http.ResponseWriter
	status       int
	responseBody []byte
}

func (r *responseRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (r *responseRecorder) Write(body []byte) (int, error) {
	r.responseBody = append(r.responseBody, body...)
	return r.ResponseWriter.Write(body)
}

// --- middleware

func WithLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec := &responseRecorder{ResponseWriter: w, status: http.StatusOK}
		start := time.Now()
		next.ServeHTTP(rec, r)
		log.Printf("%s %s %s %d %s", r.Method, r.URL.Path, time.Since(start), rec.status, rec.responseBody)
	})
}
