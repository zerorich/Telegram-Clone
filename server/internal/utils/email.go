package utils

import (
	"fmt"
	"net/smtp"
)

type EmailSender struct {
	host     string
	port     string
	user     string
	password string
	from     string
}

func NewEmailSender(host, port, user, password, from string) *EmailSender {
	return &EmailSender{
		host:     host,
		port:     port,
		user:     user,
		password: password,
		from:     from,
	}
}

func (e *EmailSender) SendOTP(to, code string) error {
	subject := "Your verification code"
	body := fmt.Sprintf("Subject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nYour verification code is: %s\r\nIt expires in 10 minutes.", subject, code)
	addr := fmt.Sprintf("%s:%s", e.host, e.port)
	auth := smtp.PlainAuth("", e.user, e.password, e.host)
	return smtp.SendMail(addr, auth, e.from, []string{to}, []byte(body))
}
