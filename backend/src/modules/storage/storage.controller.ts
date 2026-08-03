import { Body, Controller, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { StorageService } from './storage.service';
import { RequestUploadDto } from './dto/storage.dto';

@ApiBearerAuth()
@ApiTags('storage')
@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Post('presigned-upload')
  @ApiOperation({
    summary:
      'S3/R2 uyumlu depolamaya doğrudan (backend bypass) dosya yüklemek için kısa ömürlü presigned URL üretir.',
  })
  requestUpload(@CurrentUser('userId') userId: string, @Body() dto: RequestUploadDto) {
    return this.storageService.createPresignedUpload(userId, dto);
  }
}
