import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { MessagesService } from './messages.service';
import { AddReactionDto, CreateMessageDto, ListMessagesQueryDto, UpdateMessageDto } from './dto/messages.dto';

/**
 * Sunucu KANALLARI için mesaj uç noktaları.
 * Özel mesajlar (DM) için bkz. `dm.controller.ts` (aynı MessagesService'i
 * `{ dmChannelId }` kapsamıyla kullanır).
 */
@ApiBearerAuth()
@ApiTags('messages')
@Controller('channels/:channelId/messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get()
  @ApiOperation({ summary: 'Kanaldaki mesajları imleç tabanlı sayfalama ile listeler.' })
  list(
    @Param('channelId') channelId: string,
    @CurrentUser('userId') userId: string,
    @Query() query: ListMessagesQueryDto,
  ) {
    return this.messagesService.list({ channelId }, userId, query);
  }

  @Get(':messageId')
  @ApiOperation({ summary: 'Tek bir mesajı getirir.' })
  getOne(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.getOne({ channelId }, userId, messageId);
  }

  @Post()
  @ApiOperation({ summary: 'Kanala yeni mesaj gönderir (metin, yanıt ve/veya ekler).' })
  create(
    @Param('channelId') channelId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateMessageDto,
  ) {
    return this.messagesService.create({ channelId }, userId, dto);
  }

  @Patch(':messageId')
  @ApiOperation({ summary: 'Kendi mesajınızın içeriğini düzenler.' })
  update(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateMessageDto,
  ) {
    return this.messagesService.update({ channelId }, userId, messageId, dto);
  }

  @Delete(':messageId')
  @ApiOperation({ summary: 'Mesajı siler (kendi mesajınız veya MANAGE_MESSAGES yetkisiyle).' })
  remove(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.remove({ channelId }, userId, messageId);
  }

  @Post(':messageId/pin')
  @ApiOperation({ summary: 'Mesajı sabitler (MANAGE_MESSAGES yetkisi gerektirir).' })
  pin(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.togglePin({ channelId }, userId, messageId, true);
  }

  @Delete(':messageId/pin')
  @ApiOperation({ summary: 'Mesajın sabitlemesini kaldırır (MANAGE_MESSAGES yetkisi gerektirir).' })
  unpin(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.togglePin({ channelId }, userId, messageId, false);
  }

  @Post(':messageId/reactions')
  @ApiOperation({ summary: 'Mesaja emoji tepkisi ekler.' })
  addReaction(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: AddReactionDto,
  ) {
    return this.messagesService.addReaction({ channelId }, userId, messageId, dto);
  }

  @Delete(':messageId/reactions/:emoji')
  @ApiOperation({ summary: 'Kendi emoji tepkinizi kaldırır.' })
  removeReaction(
    @Param('channelId') channelId: string,
    @Param('messageId') messageId: string,
    @Param('emoji') emoji: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.removeReaction({ channelId }, userId, messageId, decodeURIComponent(emoji));
  }
}
