import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { MessagesService } from '@/modules/messages/messages.service';
import {
  AddReactionDto,
  CreateMessageDto,
  ListMessagesQueryDto,
  UpdateMessageDto,
} from '@/modules/messages/dto/messages.dto';
import { DmService } from './dm.service';
import { CreateDmChannelDto } from './dto/dm.dto';

@ApiBearerAuth()
@ApiTags('direct-messages')
@Controller('dm-channels')
export class DmController {
  constructor(
    private readonly dmService: DmService,
    private readonly messagesService: MessagesService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Kullanıcının dahil olduğu tüm özel mesaj kanallarını listeler.' })
  listMine(@CurrentUser('userId') userId: string) {
    return this.dmService.listMine(userId);
  }

  @Post()
  @ApiOperation({ summary: 'Birebir ya da grup özel mesaj kanalı oluşturur (varsa mevcut olanı döner).' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreateDmChannelDto) {
    return this.dmService.createOrGet(userId, dto);
  }

  @Get(':dmChannelId')
  @ApiOperation({ summary: 'Bir özel mesaj kanalının detaylarını getirir.' })
  getOne(@Param('dmChannelId') dmChannelId: string, @CurrentUser('userId') userId: string) {
    return this.dmService.getOne(dmChannelId, userId);
  }

  @Post(':dmChannelId/read')
  @ApiOperation({ summary: 'Kanalı okundu olarak işaretler.' })
  markRead(@Param('dmChannelId') dmChannelId: string, @CurrentUser('userId') userId: string) {
    return this.dmService.markRead(dmChannelId, userId);
  }

  // -------------------------------------------------------------------
  // MESAJLAR (aynı MessagesService, {dmChannelId} kapsamıyla kullanılır)
  // -------------------------------------------------------------------

  @Get(':dmChannelId/messages')
  @ApiOperation({ summary: 'DM kanalındaki mesajları imleç tabanlı sayfalama ile listeler.' })
  listMessages(
    @Param('dmChannelId') dmChannelId: string,
    @CurrentUser('userId') userId: string,
    @Query() query: ListMessagesQueryDto,
  ) {
    return this.messagesService.list({ dmChannelId }, userId, query);
  }

  @Post(':dmChannelId/messages')
  @ApiOperation({ summary: 'DM kanalına mesaj gönderir.' })
  sendMessage(
    @Param('dmChannelId') dmChannelId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateMessageDto,
  ) {
    return this.messagesService.create({ dmChannelId }, userId, dto);
  }

  @Patch(':dmChannelId/messages/:messageId')
  @ApiOperation({ summary: 'Kendi DM mesajınızı düzenler.' })
  updateMessage(
    @Param('dmChannelId') dmChannelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateMessageDto,
  ) {
    return this.messagesService.update({ dmChannelId }, userId, messageId, dto);
  }

  @Delete(':dmChannelId/messages/:messageId')
  @ApiOperation({ summary: 'Kendi DM mesajınızı siler.' })
  removeMessage(
    @Param('dmChannelId') dmChannelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.remove({ dmChannelId }, userId, messageId);
  }

  @Post(':dmChannelId/messages/:messageId/reactions')
  @ApiOperation({ summary: 'DM mesajına emoji tepkisi ekler.' })
  addReaction(
    @Param('dmChannelId') dmChannelId: string,
    @Param('messageId') messageId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: AddReactionDto,
  ) {
    return this.messagesService.addReaction({ dmChannelId }, userId, messageId, dto);
  }

  @Delete(':dmChannelId/messages/:messageId/reactions/:emoji')
  @ApiOperation({ summary: 'Kendi emoji tepkinizi kaldırır.' })
  removeReaction(
    @Param('dmChannelId') dmChannelId: string,
    @Param('messageId') messageId: string,
    @Param('emoji') emoji: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.messagesService.removeReaction({ dmChannelId }, userId, messageId, decodeURIComponent(emoji));
  }
}
