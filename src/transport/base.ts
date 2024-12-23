import type { NotificationMessage, RequestMessage, ResponseMessage } from '../msgpackRpcProtocol';
import type { RpcService } from '../rpcService';
import { serializeMessage } from '../msgpackRpcProtocol';

export abstract class BaseTransport {
  constructor(private server: RpcService) {}

  abstract sendData(data: Uint8Array): void;
  async onRequest(message: RequestMessage) {
    await this.server.dispatchMethod(message, (response: ResponseMessage) => {
      this.sendData(serializeMessage(response));
    });
  }

  async onNotify(message: NotificationMessage) {
    this.server.dispatchMethod(message);
  }
}
