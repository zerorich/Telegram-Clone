package services

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

type UserService struct {
	users *repository.UserRepository
	files *utils.FileStore
}

func NewUserService(users *repository.UserRepository, files *utils.FileStore) *UserService {
	return &UserService{users: users, files: files}
}

func (s *UserService) GetMe(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	return s.users.GetByID(ctx, userID)
}

func (s *UserService) GetByID(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	return s.users.GetByID(ctx, userID)
}

func (s *UserService) UpdateMe(ctx context.Context, userID uuid.UUID, name string, surname *string, username *string) (*models.User, error) {
	if username != nil && *username != "" {
		taken, err := s.users.UsernameTaken(ctx, *username, userID)
		if err != nil {
			return nil, err
		}
		if taken {
			return nil, errors.New("username already taken")
		}
	}
	return s.users.Update(ctx, userID, name, surname, username)
}

func (s *UserService) UploadAvatar(ctx context.Context, userID uuid.UUID, data []byte) (*models.User, error) {
	processed, ext, err := utils.ProcessAvatar(data)
	if err != nil {
		return nil, err
	}
	path, err := s.files.Save(utils.CategoryAvatar, processed, ext)
	if err != nil {
		return nil, err
	}
	return s.users.UpdateAvatar(ctx, userID, path)
}

func (s *UserService) Search(ctx context.Context, query string) ([]models.User, error) {
	return s.users.Search(ctx, query, 20)
}

func (s *UserService) SanitizeUser(u *models.User) *models.User {
	if u == nil {
		return nil
	}
	copy := *u
	copy.PasswordHash = ""
	return &copy
}
