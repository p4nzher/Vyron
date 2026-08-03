import { Module } from '@nestjs/common';
import { MessagesModule } from '@/modules/messages/messages.module';
import { VoiceService } from './voice.service';
import { VoiceController } from './voice.controller';
import { LiveKitService } from './livekit.service';

@Module({
  imports: [MessagesModule], // MessagesGateway'i (oda yayını için) yeniden kullanır
  controllers: [VoiceController],
  providers: [VoiceService, LiveKitService],
  exports: [VoiceService],
})
export class VoiceModule {}
