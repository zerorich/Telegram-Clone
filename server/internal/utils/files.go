package utils

import (
	"bytes"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/disintegration/imaging"
	"github.com/google/uuid"
	_ "golang.org/x/image/webp"
)

type MediaCategory string

const (
	CategoryAvatar  MediaCategory = "avatars"
	CategoryImage   MediaCategory = "images"
	CategoryVideo   MediaCategory = "videos"
	CategoryVoice   MediaCategory = "voice"
	CategoryFile    MediaCategory = "files"
)

var (
	maxAvatarSize  int64 = 5 << 20
	maxImageSize   int64 = 20 << 20
	maxVideoSize   int64 = 100 << 20
	maxVoiceSize   int64 = 10 << 20
	maxFileSize    int64 = 50 << 20
)

type FileStore struct {
	uploadDir string
	baseURL   string
}

func NewFileStore(uploadDir, baseURL string) *FileStore {
	return &FileStore{uploadDir: uploadDir, baseURL: baseURL}
}

func (f *FileStore) EnsureDirs() error {
	for _, dir := range []string{"avatars", "images", "videos", "voice", "files"} {
		if err := os.MkdirAll(filepath.Join(f.uploadDir, dir), 0755); err != nil {
			return err
		}
	}
	return nil
}

func (f *FileStore) Save(category MediaCategory, data []byte, ext string) (string, error) {
	now := time.Now()
	name := uuid.New().String() + ext
	rel := filepath.ToSlash(filepath.Join(string(category), fmt.Sprintf("%d", now.Year()), fmt.Sprintf("%02d", int(now.Month())), name))
	full := filepath.Join(f.uploadDir, rel)
	if err := os.MkdirAll(filepath.Dir(full), 0755); err != nil {
		return "", err
	}
	if err := os.WriteFile(full, data, 0644); err != nil {
		return "", err
	}
	return "/uploads/" + rel, nil
}

func (f *FileStore) PublicURL(path string) string {
	if strings.HasPrefix(path, "http") {
		return path
	}
	return strings.TrimRight(f.baseURL, "/") + path
}

func (f *FileStore) FullPath(urlPath string) string {
	rel := strings.TrimPrefix(urlPath, "/uploads/")
	return filepath.Join(f.uploadDir, filepath.FromSlash(rel))
}

func DetectMIME(data []byte) string {
	if len(data) < 12 {
		return ""
	}
	// JPEG
	if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
		return "image/jpeg"
	}
	// PNG
	if bytes.HasPrefix(data, []byte{0x89, 0x50, 0x4E, 0x47}) {
		return "image/png"
	}
	// WEBP
	if len(data) >= 12 && string(data[0:4]) == "RIFF" && string(data[8:12]) == "WEBP" {
		return "image/webp"
	}
	// ISO BMFF (ftyp) — check audio brands before video
	if len(data) >= 12 && string(data[4:8]) == "ftyp" {
		brand := string(data[8:12])
		switch brand {
		case "M4A ", "M4B ", "mp42", "isom":
			return "audio/mp4"
		case "qt  ":
			return "video/quicktime"
		default:
			return "video/mp4"
		}
	}
	// OGG
	if bytes.HasPrefix(data, []byte("OggS")) {
		return "audio/ogg"
	}
	// WEBM
	if len(data) >= 4 && data[0] == 0x1A && data[1] == 0x45 && data[2] == 0xDF && data[3] == 0xA3 {
		return "audio/webm"
	}
	return "application/octet-stream"
}

func MIMEFromFilename(name string) string {
	ext := strings.ToLower(filepath.Ext(name))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".mp4":
		return "video/mp4"
	case ".mov":
		return "video/quicktime"
	case ".m4a", ".aac":
		return "audio/mp4"
	case ".ogg":
		return "audio/ogg"
	case ".webm":
		return "audio/webm"
	default:
		return ""
	}
}

func ExtForMIME(mime string) string {
	switch mime {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "video/mp4":
		return ".mp4"
	case "video/quicktime":
		return ".mov"
	case "audio/ogg":
		return ".ogg"
	case "audio/webm":
		return ".webm"
	case "audio/mp4":
		return ".m4a"
	default:
		return ".bin"
	}
}

func ValidateMedia(mime string, size int64, allowed []string, maxSize int64) error {
	if size > maxSize {
		return fmt.Errorf("file too large")
	}
	for _, a := range allowed {
		if mime == a {
			return nil
		}
	}
	return fmt.Errorf("unsupported file type: %s", mime)
}

func ReadAllLimited(r io.Reader, max int64) ([]byte, error) {
	return io.ReadAll(io.LimitReader(r, max+1))
}

func ProcessAvatar(data []byte) ([]byte, string, error) {
	mime := DetectMIME(data)
	if mime != "image/jpeg" && mime != "image/png" {
		return nil, "", fmt.Errorf("avatar must be JPEG or PNG")
	}
	if int64(len(data)) > maxAvatarSize {
		return nil, "", fmt.Errorf("avatar too large")
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, "", err
	}
	resized := imaging.Fit(img, 256, 256, imaging.Lanczos)
	var buf bytes.Buffer
	ext := ".jpg"
	if mime == "image/png" {
		ext = ".png"
		if err := imaging.Encode(&buf, resized, imaging.PNG); err != nil {
			return nil, "", err
		}
	} else {
		if err := imaging.Encode(&buf, resized, imaging.JPEG, imaging.JPEGQuality(85)); err != nil {
			return nil, "", err
		}
	}
	return buf.Bytes(), ext, nil
}

func AllowedImageMIMEs() []string {
	return []string{"image/jpeg", "image/png", "image/webp"}
}

func AllowedVideoMIMEs() []string {
	return []string{"video/mp4", "video/quicktime"}
}

func AllowedVoiceMIMEs() []string {
	return []string{"audio/ogg", "audio/webm", "audio/mp4"}
}
