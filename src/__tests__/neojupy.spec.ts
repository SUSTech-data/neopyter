import { ServerConnection } from '@jupyterlab/services';
import { URLExt } from '@jupyterlab/coreutils';
import { RpcServer } from '../rpcServer';
import { WebsocketTransport } from '../transport';

/**
 * Example of [Jest](https://jestjs.io/docs/getting-started) unit tests
 */

describe('neopyter', () => {
  it('simple rpc call', () => {
    const settings = ServerConnection.makeSettings();
    const url = URLExt.join(settings.wsUrl, 'neopyter', 'channel');

    expect(new Promise((resolve, reject) => {
      const server = new RpcServer({
        echo: (message: string) => {
          resolve(message)
          return `hello: ${message}`;
        }
      });
      server.start(WebsocketTransport, url);
      // server.transport!.onRead(
      //   serializeMessage({
      //     type: MessageType.Request,
      //     msgid: 0,
      //     method: 'echo',
      //     params: ['World']
      //   })
      // );
    })).resolves.toBe("World")
  });
});
