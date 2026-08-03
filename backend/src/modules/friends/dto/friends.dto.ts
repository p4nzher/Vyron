import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsUUID, Matches } from 'class-validator';

export class SendFriendRequestDto {
  @ApiProperty({
    example: 'enes_dev#0472',
    description: 'Hedef kullanıcının "kullaniciadi#discriminator" formatı',
  })
  @IsString()
  @Matches(/^.{3,32}#\d{4}$/, {
    message: 'Kullanıcı etiketi "kullaniciadi#0000" formatında olmalıdır.',
  })
  usernameTag: string;
}

export class RespondFriendRequestDto {
  @ApiProperty({ description: 'Yanıtlanacak arkadaşlık isteğinin ID’si' })
  @IsUUID()
  friendshipId: string;
}

export class UserIdParamDto {
  @ApiProperty()
  @IsUUID()
  userId: string;
}
