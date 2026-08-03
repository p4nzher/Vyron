import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Request } from 'express';

export interface JwtRefreshPayload {
  sub: string;
  tokenId: string; // RefreshToken tablosundaki kayıt ID'si (iptal/rotasyon için)
}

/**
 * Uzun ömürlü (30 gün) refresh token'ları doğrulayan strateji.
 * Body içinde gönderilen refreshToken alanından okunur ve request.refreshToken'a
 * ham token değeri de eklenir ki servis katmanı hash karşılaştırması yapabilsin.
 */
@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromBodyField('refreshToken'),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.refreshSecret') as string,
      passReqToCallback: true,
    });
  }

  async validate(req: Request, payload: JwtRefreshPayload) {
    const refreshToken = req.body?.refreshToken;
    return { userId: payload.sub, tokenId: payload.tokenId, refreshToken };
  }
}
