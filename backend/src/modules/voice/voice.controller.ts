import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { VoiceService } from './voice.service';
import { MoveMemberDto, UpdateVoiceStateDto } from './dto/voice.dto';

@ApiBearerAuth()
@ApiTags('voice')
@Controller('channels/:channelId/voice')
export class VoiceController {
  constructor(private readonly voiceService: VoiceService) {}

  @Post('join')
  @ApiOperation({ summary: 'Sesli/görüntülü kanala katılır ve LiveKit erişim token’ı üretir.' })
  join(
    @Param('channelId') channelId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('username') username: string,
  ) {
    return this.voiceService.join(channelId, userId, username);
  }

  @Post('leave')
  @ApiOperation({ summary: 'Sesli/görüntülü kanaldan ayrılır.' })
  leave(@Param('channelId') channelId: string, @CurrentUser('userId') userId: string) {
    return this.voiceService.leave(channelId, userId);
  }

  @Patch('state')
  @ApiOperation({ summary: 'Kendi mikrofon/kamera/ekran paylaşımı durumunu günceller.' })
  updateState(
    @Param('channelId') channelId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateVoiceStateDto,
  ) {
    return this.voiceService.updateOwnState(channelId, userId, dto);
  }

  @Get('participants')
  @ApiOperation({ summary: 'Kanaldaki mevcut sesli katılımcıları listeler.' })
  listParticipants(@Param('channelId') channelId: string, @CurrentUser('userId') userId: string) {
    return this.voiceService.listParticipants(channelId, userId);
  }

  @Post('members/:userId/mute')
  @ApiOperation({ summary: 'Bir üyeyi zorla susturur (MUTE_MEMBERS_VOICE gerektirir).' })
  forceMute(
    @Param('channelId') channelId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
  ) {
    return this.voiceService.forceMute(channelId, actorId, targetUserId, true);
  }

  @Delete('members/:userId/mute')
  @ApiOperation({ summary: 'Bir üyenin zorla susturmasını kaldırır.' })
  unMute(
    @Param('channelId') channelId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
  ) {
    return this.voiceService.forceMute(channelId, actorId, targetUserId, false);
  }

  @Post('members/:userId/deafen')
  @ApiOperation({ summary: 'Bir üyeyi zorla sağırlaştırır (DEAFEN_MEMBERS_VOICE gerektirir).' })
  forceDeafen(
    @Param('channelId') channelId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
  ) {
    return this.voiceService.forceDeafen(channelId, actorId, targetUserId, true);
  }

  @Delete('members/:userId/deafen')
  @ApiOperation({ summary: 'Bir üyenin zorla sağırlaştırmasını kaldırır.' })
  unDeafen(
    @Param('channelId') channelId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
  ) {
    return this.voiceService.forceDeafen(channelId, actorId, targetUserId, false);
  }

  @Post('members/:userId/move')
  @ApiOperation({ summary: 'Bir üyeyi başka bir sesli kanala taşır (MOVE_MEMBERS_VOICE gerektirir).' })
  move(
    @Param('channelId') channelId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
    @Body() dto: MoveMemberDto,
  ) {
    return this.voiceService.moveMember(channelId, actorId, targetUserId, dto.targetChannelId);
  }

  @Delete('members/:userId')
  @ApiOperation({ summary: 'Bir üyeyi sesli kanaldan zorla atar (MOVE_MEMBERS_VOICE gerektirir).' })
  disconnect(
    @Param('channelId') channelId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
  ) {
    return this.voiceService.disconnectMember(channelId, actorId, targetUserId);
  }
}
