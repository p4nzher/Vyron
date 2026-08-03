import * as Joi from 'joi';

/**
 * Uygulama ayağa kalkmadan önce gerekli tüm ortam değişkenlerinin
 * var olduğunu ve doğru formatta olduğunu garanti eden validasyon şeması.
 * Eksik/yanlış bir env değişkeni varsa uygulama başlamadan hata fırlatır —
 * bu, "production'da runtime'da patlama" senaryosunu önler.
 */
export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
  PORT: Joi.number().default(3000),

  DATABASE_URL: Joi.string().required(),

  REDIS_HOST: Joi.string().required(),
  REDIS_PORT: Joi.number().default(6379),

  JWT_ACCESS_SECRET: Joi.string().min(32).required(),
  JWT_REFRESH_SECRET: Joi.string().min(32).required(),

  S3_ENDPOINT: Joi.string().uri().required(),
  S3_BUCKET_NAME: Joi.string().required(),

  LIVEKIT_URL: Joi.string().required(),
  LIVEKIT_API_KEY: Joi.string().required(),
  LIVEKIT_API_SECRET: Joi.string().required(),
});
