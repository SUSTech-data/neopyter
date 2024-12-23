import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { MessageType } from '../msgpackRpcProtocol';
import { RpcService } from '../rpcService';
import { WebsocketTransport } from '../transport';

/**
 * Example of [Jest](https://jestjs.io/docs/getting-started) unit tests
 */

describe('neopyter', () => {
  it('simple rpc call', () => {
    const settings = ServerConnection.makeSettings();
    const url = URLExt.join(settings.wsUrl, 'neopyter', 'channel');

    expect(
      new Promise((resolve, _reject) => {
        const server = new RpcService({
          echo: (message: string) => {
            resolve(message);
          },
        });
        server.start(WebsocketTransport, url, false);
        server.transport!.onRequest({
          type: MessageType.Request,
          msgid: 0,
          method: 'echo',
          params: ['World'],
        });
        // mock
        const transport = server.transport as any;
        transport.sendData = () => {
          transport.websocket.close();
        };
      }),
    ).resolves.toBe('World');
  });
});
