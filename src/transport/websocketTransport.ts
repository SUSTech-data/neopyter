import type { Message } from '../msgpackRpcProtocol';
import type { RpcService } from '../rpcService';
import { RPCError } from '../error';
import logger from '../logger';
import { deserializeStream, MessageType } from '../msgpackRpcProtocol';
import { BaseTransport } from './base';

function base64ToBytes(str: string) {
  const binString = atob(str);
  return Uint8Array.from(binString, m => m.codePointAt(0)!);
}

function bytesToBase64(bytes: Uint8Array) {
  const binString = String.fromCodePoint(...bytes);
  return btoa(binString);
}

export class WebsocketTransport extends BaseTransport {
  private websocket?: WebSocket;
  private readableStream?: ReadableStream;
  constructor(
    server: RpcService,
    private url: string,
    private autoRetry: boolean,
  ) {
    super(server);
    this.start();
  }

  async start() {
    try {
      this.websocket = new WebSocket(this.url);
      this.websocket.binaryType = 'arraybuffer';
      this.readableStream = new ReadableStream({
        start: (controller) => {
          this.websocket!.addEventListener('open', (event) => {
            this.onOpen(event);
          });
          this.websocket!.addEventListener('message', (event) => {
            const buf = base64ToBytes(event.data);
            controller.enqueue(buf);
          });

          this.websocket!.addEventListener('error', (event) => {
            this.onError(event);
            throw event;
          });
          this.websocket!.addEventListener('close', (event) => {
            this.onClose(event);
            controller.close();
          });
        },
      });
      for await (const message of deserializeStream(this.readableStream)) {
        logger.info(message);
        this.onRead(message);
      }
    }
    catch (e) {
      logger.error(e);
      this.checkRetry();
      throw e;
    }
  }

  async onRead(message: Message) {
    switch (message.type) {
      case MessageType.Request:
        await this.onRequest(message);
        break;
      case MessageType.Notification:
        await this.onNotify(message);
        break;
      default:
        throw new RPCError(`unknown message: ${message}`);
    }
  }

  sendData(data: Uint8Array): void {
    this.websocket!.send(bytesToBase64(data));
  }

  protected onOpen(_event: Event) {
    logger.info(`connection websocket ${this.websocket!.url}`);
  }

  protected onError(event: Event) {
    logger.error('websocket error', event);
  }

  protected onClose(event: Event) {
    logger.info(`disconnect websocket: ${this.websocket!.url}`, event);
    this.websocket!.close();
    this.websocket = undefined;
    this.readableStream = undefined;
    this.checkRetry();
  }

  protected checkRetry() {
    if (this.autoRetry && this.websocket === undefined) {
      logger.info('reconnect websocket server after 1s');
      setTimeout(() => {
        if (this.autoRetry && this.websocket === undefined) {
          this.start();
        }
        else {
          logger.error('check reconnect repeat');
        }
      }, 1000);
    }
  }
}
