/**
 * Merkezi uygulama konfigürasyonu.
 * Tüm ortam değişkenleri burada tip güvenli şekilde okunur ve
 * ConfigModule aracılığıyla tüm uygulamaya enjekte edilir.
 */
export default () => ({
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  // Faz 7.1: 'api/v1' DEĞİL 'api' olmalı — 'v1' segmenti main.ts'teki
  // `app.enableVersioning({ defaultVersion: '1' })` tarafından ayrıca
  // ekleniyor (bkz. main.ts'teki ayrıntılı not).
  apiPrefix: process.env.API_PREFIX || 'api',
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').filter(Boolean),
  // Faz 7.3 — bkz. `common/logging/logging.module.ts`. Boşsa: production'da
  // 'info', development'ta 'debug'.
  logLevel: process.env.LOG_LEVEL || '',

  database: {
    url: process.env.DATABASE_URL,
  },

  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || undefined,
    tls: process.env.REDIS_TLS === 'true',
  },

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },

  s3: {
    endpoint: process.env.S3_ENDPOINT,
    region: process.env.S3_REGION || 'auto',
    accessKeyId: process.env.S3_ACCESS_KEY_ID,
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
    bucketName: process.env.S3_BUCKET_NAME,
    publicUrl: process.env.S3_PUBLIC_URL,
  },

  liveKit: {
    url: process.env.LIVEKIT_URL,
    apiKey: process.env.LIVEKIT_API_KEY,
    apiSecret: process.env.LIVEKIT_API_SECRET,
  },

  mail: {
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    user: process.env.SMTP_USER,
    password: process.env.SMTP_PASSWORD,
    from: process.env.MAIL_FROM || 'no-reply@localhost',
  },

  rateLimit: {
    ttl: parseInt(process.env.RATE_LIMIT_TTL || '60', 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  },
});
