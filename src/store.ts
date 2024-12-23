import type { Dispatcher } from './rpcService';
import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import logger from './logger';
import { RpcService } from './rpcService';
import { WebsocketTransport } from './transport';
import { LogLevel } from './types';
import { createSet, createUse, injectAction } from './utilitytype';

export interface IExtensionSetting {
  mode: 'direct' | 'proxy'
  ip: string
  port: number
  loglevel: LogLevel
}

const settingState = create<IExtensionSetting>()(
  persist(
    (_set, _get) => ({
      mode: 'direct',
      ip: '127.0.0.1',
      port: 9001,
      loglevel: LogLevel.error,
    }),
    {
      name: 'neopyter-setting',
    },
  ),
);
// disable rule, because of `settingStore` is defined later
/* eslint "ts/no-use-before-define": "off" */
const actions = {
  notifyJupyterServer: async () => {
    const data = JSON.stringify(settingStore.getState());
    logger.info('notify jupyter server, send:', data);
    const connectSettings = ServerConnection.makeSettings();
    const baseUrl = connectSettings.baseUrl;
    const url = URLExt.join(baseUrl, 'neopyter', 'update_settings');
    const response = await ServerConnection.makeRequest(
      url,
      {
        method: 'POST',
        body: data,
      },
      connectSettings,
    );
    logger.info('notify jupyter server, receive:', await response.json());
  },
  startConnection: async (dispatcher: Dispatcher) => {
    logger.info('start connecting..');
    const server = new RpcService(dispatcher);
    const { mode, ip, port } = settingStore.getState();
    logger.info(`current mode: ${mode}`);
    await settingStore.notifyJupyterServer();
    if (mode === 'proxy') {
      const settings = ServerConnection.makeSettings();
      const url = URLExt.join(settings.wsUrl, 'neopyter', 'channel');
      console.info(`neopyter connect to:${url}`);
      server.start(WebsocketTransport, url, false);
    }
    else {
      const url = `ws://${ip}:${port}`;
      console.info(`neopyter connect to:${url}`);
      server.start(WebsocketTransport, url, true);
    }
  },
  updateSettings: async (newSettings: IExtensionSetting) => {
    settingState.setState(newSettings);
    settingStore.notifyJupyterServer();
  },
};

export const settingStore = injectAction(createSet(createUse(settingState)), actions);
