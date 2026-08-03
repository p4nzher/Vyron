import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

export interface JwtAccessPayload {
  sub: string; // userId
  email: string;
  username: string;
}

/**
 * Kısa ömürlü (15 dk) access token'ları doğrulayan Passport stratejisi.
 * Her API isteğinde Authorization: Bearer <token> header'ından okunur.
 */
@Injectable()
export class JwtAccessStrategy extends PassportStrategy(Strategy, 'jwt-access') {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.accessSecret') as string,
    });
  }

  /**
   * Token imzası geçerliyse Passport bu metodu çağırır.
   * Dönen obje request.user olarak enjekte edilir.
   */
  async validate(payload: JwtAccessPayload) {
    return { userId: payload.sub, email: payload.email, username: payload.username };
  }
}
