import { RpcServer } from '../rpcServer';
import { BaseTransport } from './base';
import { Message, MessageType, deserializeStream } from '../msgpackRpcProtocol';
import { RPCError } from '../error';

function base64ToBytes(str: string) {
  const binString = atob(str);
  return Uint8Array.from(binString, m => m.codePointAt(0)!);
}

function bytesToBase64(bytes: Uint8Array) {
  const binString = String.fromCodePoint(...bytes);
  return btoa(binString);
}

export class WebsocketTransport extends BaseTransport {
  private websocket: WebSocket;
  private readableStream: ReadableStream;
  constructor(
    server: RpcServer,
    private url: string
  ) {
    super(server);
    this.websocket = new WebSocket(this.url);
    this.websocket.binaryType = 'arraybuffer';
    this.readableStream = new ReadableStream({
      start: controller => {
        // console.log('start');
        this.websocket.addEventListener('open', event => {
          this.onOpen(event);
        });
        this.websocket.addEventListener('message', event => {
          const buf = base64ToBytes(event.data);
          controller.enqueue(buf);
        });

        this.websocket.addEventListener('error', event => {
          this.onError(event);
          throw event;
        });
        this.websocket.addEventListener('close', event => {
          this.onClose(event);
          controller.close();
        });
      }
    });
    setTimeout(async () => {
      for await (const message of deserializeStream(this.readableStream)) {
        // console.log(message);
        this.onRead(message);
      }
    }, 0);
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
        throw new RPCError(`Unknown message: ${message}`);
    }
  }

  sendData(data: Uint8Array): void {
    this.websocket.send(bytesToBase64(data));
  }

  protected onOpen(_event: Event) {
    console.log(`Connection to neopyter jupyter server by websocket ${this.websocket.url}`);
  }
  protected onError(event: Event) {
    console.error('Websocket error', event);
  }
  protected onClose(_event: Event) {
    console.log(`DisConnection to neopyter jupyter server by websocket ${this.websocket.url}`);
  }
}
