import { decode, decodeMultiStream, encode } from '@msgpack/msgpack';
import { RPCError } from './error';

const errorRef = 'https://github.com/msgpack-rpc/msgpack-rpc/blob/master/spec.md';

export enum MessageType {
  Request = 0,
  Response = 1,
  Notification = 2,
}

export interface RequestMessage {
  type: MessageType.Request
  msgid: number // 32-bit unsigned integer number.
  method: string
  params: unknown[]
}

export interface ResponseMessage {
  type: MessageType.Response
  msgid: number // 32-bit unsigned integer number.
  error?: Error
  result?: unknown[]
}

export interface NotificationMessage {
  type: MessageType.Notification
  method: string
  params: unknown[]
}

export type Message = RequestMessage | ResponseMessage | NotificationMessage;

export function deserializeMessage(data: Uint8Array): Message {
  const message = decode(data);
  if (!Array.isArray(message) || (message.length !== 4 && message.length !== 3)) {
    throw new RPCError(`Invalid msgpack-rpc message: ${JSON.stringify(message)}, please reference ${errorRef}`);
  }
  const msgType = message[0];
  if (msgType !== 0 && msgType !== 1 && msgType !== 2) {
    throw new RPCError(`Invalid msgpack-rpc message: ${JSON.stringify(message)}, please reference ${errorRef}`);
  }

  if (msgType === MessageType.Request) {
    return { type: MessageType.Request, msgid: message[1], method: message[2], params: message[3] };
  }
  else if (msgType === MessageType.Response) {
    return { type: MessageType.Response, msgid: message[1], error: message[2], result: message[3] };
  }
  return { type: MessageType.Notification, method: message[1], params: message[2] };
}

export function serializeMessage(message: Message): Uint8Array {
  if (message.type === MessageType.Request) {
    return encode([message.type, message.msgid, message.method, message.params]);
  }
  else if (message.type === MessageType.Response) {
    return encode([message.type, message.msgid, message.error ? message.error.toString() : undefined, message.result]);
  }
  return encode([message.type, message.method, message.params]);
}
export async function* deserializeStream(stream: ReadableStream) {
  // const ss = decodeArrayStream(stream);
  const ss = decodeMultiStream(stream);
  for await (const message of ss) {
    if (!Array.isArray(message) || (message.length !== 4 && message.length !== 3)) {
      throw new RPCError(`Invalid msgpack-rpc message: ${JSON.stringify(message)}, please reference ${errorRef}`);
    }
    const msgType = message[0];
    if (msgType !== 0 && msgType !== 1 && msgType !== 2) {
      throw new RPCError(`Invalid msgpack-rpc message: ${JSON.stringify(message)}, please reference ${errorRef}`);
    }

    if (msgType === MessageType.Request) {
      yield { type: MessageType.Request, msgid: message[1], method: message[2], params: message[3] } as RequestMessage;
    }
    else if (msgType === MessageType.Response) {
      yield { type: MessageType.Response, msgid: message[1], error: message[2], result: message[3] } as ResponseMessage;
    }
    else {
      yield { type: MessageType.Notification, method: message[1], params: message[2] } as NotificationMessage;
    }
  }
}
