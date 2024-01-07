import { MessageType, NotificationMessage, RequestMessage, ResponseMessage } from './msgpackRpcProtocol';
import { BaseTransport } from './transport';
import { RPCError } from './error';

export type Dispatcher = { [key: string]: (...args: any[]) => unknown };

export class RpcServer {
  transport?: BaseTransport;
  constructor(private dispatcher: Dispatcher) {}

  start<T extends BaseTransport, PT extends unknown[]>(
    transportCtr: new (server: RpcServer, ...args: PT) => T,
    ...params: PT
  ) {
    this.transport = new transportCtr(this, ...params);
  }

  async dispatchMethod(message: RequestMessage | NotificationMessage, responseFn?: (message: ResponseMessage) => void) {
    if (!this.dispatcher[message.method]) {
      const error = new RPCError(`Method not found ${message.method}`);
      if (message.type === MessageType.Request && responseFn) {
        responseFn({
          type: MessageType.Response,
          msgid: message.msgid,
          error,
          result: undefined
        });
      }
      throw error;
    }
    try {
      const result = await this.dispatcher[message.method](...message.params);
      if (message.type === MessageType.Request && responseFn) {
        responseFn({
          type: MessageType.Response,
          msgid: message.msgid,
          result: result as unknown[]
        });
      }
    } catch (error: unknown) {
      console.error(error);
      if (message.type === MessageType.Request && responseFn) {
        responseFn({
          type: MessageType.Response,
          msgid: message.msgid,
          error: error as Error
        });
      }
    }
  }
}
