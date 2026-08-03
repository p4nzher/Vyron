import { Module } from '@nestjs/common';
import { MessagesModule } from '@/modules/messages/messages.module';
import { DmService } from './dm.service';
import { DmController } from './dm.controller';

@Module({
  imports: [MessagesModule],
  controllers: [DmController],
  providers: [DmService],
  exports: [DmService],
})
export class DmModule {}
