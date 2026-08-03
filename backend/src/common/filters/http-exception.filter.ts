import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Uygulama genelinde fırlatılan tüm hataları (HttpException ve beklenmedik
 * runtime hataları dahil) tek, tutarlı bir JSON formatına dönüştürür.
 * Bu, frontend'in hata yönetimini kolaylaştırır ve stack trace gibi
 * hassas bilgilerin client'a sızmasını engeller.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Sunucu tarafında beklenmeyen bir hata oluştu.';
    let errorCode: string | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else if (typeof exceptionResponse === 'object') {
        const body = exceptionResponse as Record<string, unknown>;
        message = (body.message as string | string[]) || message;
        errorCode = body.code as string | undefined;
      }
    } else if (exception instanceof Error) {
      // Beklenmeyen hatalar detaylı olarak sadece sunucu loglarına yazılır.
      this.logger.error(`${request.method} ${request.url} - ${exception.message}`, exception.stack);
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      message,
      errorCode,
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }
}
