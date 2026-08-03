import { apiFetch } from './apiClient';

export interface PublicUser {
  id: string;
  username: string;
  discriminator: string;
  email: string;
  displayName: string | null;
  avatarUrl: string | null;
  status: string;
  twoFactorEnabled: boolean;
}

interface LoginResponse {
  user: PublicUser;
  tokens: { accessToken: string; refreshToken: string };
}

export function login(email: string, password: string, twoFactorCode?: string): Promise<LoginResponse> {
  return apiFetch<LoginResponse>('/auth/login', {
    method: 'POST',
    body: { email, password, ...(twoFactorCode ? { twoFactorCode } : {}) },
  });
}
