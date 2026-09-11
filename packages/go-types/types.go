package gotypes

type User struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Nickname *string `json:"nickname,omitempty"`
}
