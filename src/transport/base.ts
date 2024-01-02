import { RequestMessage, NotificationMessage, ResponseMessage, serializeMessage } from '../msgpackRpcProtocol';
import { RpcServer } from '../rpcServer';

export abstract class BaseTransport {
  constructor(private server: RpcServer) {}

  abstract sendData(data: Uint8Array): void;
  async onRequest(message: RequestMessage) {
    await this.server.dispatchMethod(message, (response: ResponseMessage) => {
      this.sendData(serializeMessage(response));
    });
  }
  async onNotify(message: NotificationMessage) {
    this.server.dispatchMethod(message);
  }

  // async onRead(data: Uint8Array) {
  //   const message = deserializeMessage(data);
  //   switch (message.type) {
  //     case MessageType.Request:
  //       await this.onRequest(message);
  //       break;
  //     case MessageType.Notification:
  //       await this.onNotify(message);
  //       break;
  //     default:
  //       throw new RPCError(`Unknown message: ${message}`);
  //   }
  // }
}
