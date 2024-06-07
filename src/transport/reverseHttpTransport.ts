import { RpcService } from '../rpcService';
import { BaseTransport } from './base';

// deprecated!!! use WebsocketTransport instead
export class ReverseHttpTransport extends BaseTransport {
  // private encoder = new TextEncoder();
  constructor(
    server: RpcService,
    private url: string
  ) {
    super(server);
    this.startHeartBeat();
  }

  sendData(data: Uint8Array): void {}

  protected startHeartBeat() {
    setTimeout(async () => {
      const response = await fetch(this.url);
      const body = await response.json();
      if (body.code === 1) {
        // with new remote call
        // await this.onRead(this.encoder.encode(body.data));
      } else if (body.code !== 0) {
        console.error(body);
      }
      // start new loop, wait for 100ms
      this.startHeartBeat();
      // smaller value, faster respond
    }, 200);
  }
}
