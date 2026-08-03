import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** Sadece /auth/refresh endpoint'inde kullanılır; refresh token'ı doğrular. */
@Injectable()
export class JwtRefreshGuard extends AuthGuard('jwt-refresh') {}
