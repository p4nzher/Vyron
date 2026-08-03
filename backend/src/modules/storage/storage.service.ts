import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DeleteObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { nanoid } from 'nanoid';
import { AttachmentType } from '@prisma/client';
import { RequestUploadDto, UploadContext } from './dto/storage.dto';

/**
 * Her yükleme bağlamı için izin verilen MIME tipleri ve maksimum dosya boyutu.
 * Bu kurallar SADECE sunucu tarafında zorunlu kılınır (client tarafındaki
 * kontroller sadece UX içindir, güvenlik sınırı burasıdır).
 */
const UPLOAD_CONTEXT_RULES: Record<
  UploadContext,
  { folder: string; maxSizeBytes: number; allowedMimePrefixes: string[] }
> = {
  [UploadContext.AVATAR]: {
    folder: 'avatars',
    maxSizeBytes: 8 * 1024 * 1024,
    allowedMimePrefixes: ['image/'],
  },
  [UploadContext.BANNER]: {
    folder: 'banners',
    maxSizeBytes: 8 * 1024 * 1024,
    allowedMimePrefixes: ['image/'],
  },
  [UploadContext.SERVER_ICON]: {
    folder: 'server-icons',
    maxSizeBytes: 8 * 1024 * 1024,
    allowedMimePrefixes: ['image/'],
  },
  [UploadContext.SERVER_BANNER]: {
    folder: 'server-banners',
    maxSizeBytes: 8 * 1024 * 1024,
    allowedMimePrefixes: ['image/'],
  },
  [UploadContext.MESSAGE_ATTACHMENT]: {
    folder: 'attachments',
    maxSizeBytes: 50 * 1024 * 1024,
    allowedMimePrefixes: ['image/', 'video/', 'audio/', 'application/', 'text/'],
  },
  [UploadContext.VOICE_NOTE]: {
    folder: 'voice-notes',
    maxSizeBytes: 15 * 1024 * 1024,
    allowedMimePrefixes: ['audio/'],
  },
  [UploadContext.CUSTOM_EMOJI]: {
    folder: 'emojis',
    maxSizeBytes: 512 * 1024,
    allowedMimePrefixes: ['image/'],
  },
  [UploadContext.STICKER]: {
    folder: 'stickers',
    maxSizeBytes: 1024 * 1024,
    allowedMimePrefixes: ['image/'],
  },
};

const PRESIGNED_URL_TTL_SECONDS = 300; // 5 dakika

@Injectable()
export class StorageService {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.bucket = this.configService.get<string>('s3.bucketName') as string;
    this.publicUrl = (this.configService.get<string>('s3.publicUrl') as string) || '';
    this.client = new S3Client({
      endpoint: this.configService.get<string>('s3.endpoint'),
      region: this.configService.get<string>('s3.region') || 'auto',
      // Cloudflare R2 / MinIO gibi S3 uyumlu servisler path-style erişim ister.
      forcePathStyle: true,
      credentials: {
        accessKeyId: this.configService.get<string>('s3.accessKeyId') as string,
        secretAccessKey: this.configService.get<string>('s3.secretAccessKey') as string,
      },
    });
  }

  /**
   * İstemcinin dosyayı DOĞRUDAN S3/R2'ye (backend'i bypass ederek) yükleyebilmesi
   * için kısa ömürlü, tek kullanımlık bir "presigned PUT URL" üretir.
   * Böylece büyük dosyalar backend sunucusunun bant genişliğini/belleğini
   * tüketmez — bu, ölçeklenebilir mimarinin temel taşlarından biridir.
   */
  async createPresignedUpload(userId: string, dto: RequestUploadDto) {
    const rules = UPLOAD_CONTEXT_RULES[dto.context];

    if (dto.fileSizeBytes > rules.maxSizeBytes) {
      throw new BadRequestException(
        `'${dto.context}' bağlamı için maksimum dosya boyutu ${(rules.maxSizeBytes / (1024 * 1024)).toFixed(1)}MB'dır.`,
      );
    }
    const mimeAllowed = rules.allowedMimePrefixes.some((prefix) => dto.mimeType.startsWith(prefix));
    if (!mimeAllowed) {
      throw new BadRequestException(`'${dto.context}' bağlamı '${dto.mimeType}' tipini kabul etmiyor.`);
    }

    const sanitizedName = dto.fileName.replace(/[^a-zA-Z0-9._-]/g, '_').slice(-100);
    const key = `${rules.folder}/${userId}/${nanoid(16)}-${sanitizedName}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: dto.mimeType,
      ContentLength: dto.fileSizeBytes,
    });
    const uploadUrl = await getSignedUrl(this.client, command, { expiresIn: PRESIGNED_URL_TTL_SECONDS });

    return {
      uploadUrl,
      key,
      publicUrl: this.buildPublicUrl(key),
      expiresInSeconds: PRESIGNED_URL_TTL_SECONDS,
      attachmentType: this.inferAttachmentType(dto.mimeType, dto.context),
    };
  }

  async deleteObject(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }

  buildPublicUrl(key: string): string {
    return `${this.publicUrl.replace(/\/$/, '')}/${key}`;
  }

  /** MIME tipinden (ve bağlamdan) Prisma `AttachmentType` enum değerini çıkarır. */
  inferAttachmentType(mimeType: string, context?: UploadContext): AttachmentType {
    if (context === UploadContext.VOICE_NOTE) return AttachmentType.VOICE_NOTE;
    if (context === UploadContext.STICKER) return AttachmentType.STICKER;
    if (mimeType === 'image/gif') return AttachmentType.GIF;
    if (mimeType.startsWith('image/')) return AttachmentType.IMAGE;
    if (mimeType.startsWith('video/')) return AttachmentType.VIDEO;
    if (mimeType.startsWith('audio/')) return AttachmentType.AUDIO;
    return AttachmentType.FILE;
  }
}
