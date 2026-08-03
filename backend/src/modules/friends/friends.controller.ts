import { Body, Controller, Delete, Get, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { FriendsService } from './friends.service';
import { RespondFriendRequestDto, SendFriendRequestDto } from './dto/friends.dto';

@ApiTags('friends')
@Controller('friends')
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get()
  @ApiOperation({ summary: 'Kabul edilmiş tüm arkadaşları listeler.' })
  async listFriends(@CurrentUser('userId') userId: string) {
    return this.friendsService.listFriends(userId);
  }

  @Get('requests/incoming')
  @ApiOperation({ summary: 'Bana gelen bekleyen arkadaşlık isteklerini listeler.' })
  async incoming(@CurrentUser('userId') userId: string) {
    return this.friendsService.listIncomingRequests(userId);
  }

  @Get('requests/outgoing')
  @ApiOperation({ summary: 'Benim gönderdiğim bekleyen arkadaşlık isteklerini listeler.' })
  async outgoing(@CurrentUser('userId') userId: string) {
    return this.friendsService.listOutgoingRequests(userId);
  }

  @Post('requests')
  @ApiOperation({ summary: '"kullaniciadi#0000" etiketiyle arkadaşlık isteği gönderir.' })
  async sendRequest(@CurrentUser('userId') userId: string, @Body() dto: SendFriendRequestDto) {
    return this.friendsService.sendRequest(userId, dto.usernameTag);
  }

  @Post('requests/accept')
  @ApiOperation({ summary: 'Gelen bir arkadaşlık isteğini kabul eder.' })
  async accept(@CurrentUser('userId') userId: string, @Body() dto: RespondFriendRequestDto) {
    return this.friendsService.acceptRequest(userId, dto.friendshipId);
  }

  @Post('requests/reject')
  @ApiOperation({ summary: 'Gelen bir arkadaşlık isteğini reddeder.' })
  async reject(@CurrentUser('userId') userId: string, @Body() dto: RespondFriendRequestDto) {
    return this.friendsService.rejectRequest(userId, dto.friendshipId);
  }

  @Delete('requests/:friendshipId')
  @ApiOperation({ summary: 'Gönderdiğim bekleyen bir isteği iptal eder.' })
  async cancel(@CurrentUser('userId') userId: string, @Param('friendshipId') friendshipId: string) {
    return this.friendsService.cancelRequest(userId, friendshipId);
  }

  @Delete(':userId')
  @ApiOperation({ summary: 'Bir kullanıcıyı arkadaş listesinden çıkarır.' })
  async remove(@CurrentUser('userId') myId: string, @Param('userId') otherUserId: string) {
    return this.friendsService.removeFriend(myId, otherUserId);
  }

  @Get('blocked')
  @ApiOperation({ summary: 'Engellenen kullanıcıları listeler.' })
  async blocked(@CurrentUser('userId') userId: string) {
    return this.friendsService.listBlocked(userId);
  }

  @Post('blocked/:userId')
  @ApiOperation({ summary: 'Bir kullanıcıyı engeller (varsa arkadaşlığı otomatik kaldırır).' })
  async block(@CurrentUser('userId') myId: string, @Param('userId') targetUserId: string) {
    return this.friendsService.blockUser(myId, targetUserId);
  }

  @Delete('blocked/:userId')
  @ApiOperation({ summary: 'Engeli kaldırır.' })
  async unblock(@CurrentUser('userId') myId: string, @Param('userId') targetUserId: string) {
    return this.friendsService.unblockUser(myId, targetUserId);
  }
}
