import { useState, useEffect } from 'react';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { ISettingRegistry } from '@jupyterlab/settingregistry';
import { createSet, createUse, injectAction } from './utilitytype';

export interface IExtensionSetting {
  mode: 'direct' | 'proxy';
  ip: string;
  port: number;
}

interface ISettingState {
  settingRegistry?: ISettingRegistry;
  _ip: string;
  _port: number;
}

const settingState = create<ISettingState>()(
  persist(
    (_set, _get) => ({
      settingRegistry: undefined,
      _ip: '127.0.0.1',
      _port: 9001
    }),
    {
      name: 'neopyter-setting',
      partialize: state =>
        Object.fromEntries(Object.entries(state).filter(([key]) => !['settingRegistry'].includes(key)))
    }
  )
);

const actions = {
  getMode: async () => {
    const { settingRegistry } = settingStore.getState();
    const labSettings = await settingRegistry!.load('neopyter:labplugin');
    const mode = labSettings.composite['mode'] as 'proxy' | 'direct';
    return mode ?? 'direct';
  },

  useMode: () => {
    const { settingRegistry } = settingStore.getState();
    const [mode, setMode] = useState<IExtensionSetting['mode']>('direct');

    useEffect(() => {
      const updateMode = async () => {
        setMode(await settingStore.getMode());
      };
      const watch = async () => {
        const settings = await settingRegistry!.load('neopyter:labplugin');
        settings.changed.connect(updateMode);
      };
      watch();
      updateMode();
    }, []);

    return mode;
  },
  getIp: async () => {
    const { settingRegistry, _ip } = settingStore.getState();
    const labSettings = await settingRegistry!.load('neopyter:labplugin');
    const mode = labSettings.composite['mode'] ?? 'direct';
    if (mode === 'direct') {
      return _ip;
    } else {
      const ip = labSettings.composite['ip'] as string;
      return ip ?? '127.0.0.1';
    }
  },

  useIp: () => {
    const { settingRegistry } = settingStore();
    const [ip, setIP] = useState<IExtensionSetting['ip']>('127.0.0.1');

    useEffect(() => {
      const updateIP = async () => {
        setIP(await settingStore.getIp());
      };
      const watch = async () => {
        const settings = await settingRegistry!.load('neopyter:labplugin');
        settings.changed.connect(updateIP);
      };
      watch();
      updateIP();
    }, []);
    return ip;
  },
  getPort: async () => {
    const { settingRegistry, _port } = settingStore.getState();
    const labSettings = await settingRegistry!.load('neopyter:labplugin');
    const mode = labSettings.composite['mode'] ?? 'direct';
    if (mode === 'direct') {
      return _port;
    } else {
      const port = labSettings.composite['port'] as number;
      return port ?? 9001;
    }
  },

  usePort: () => {
    const { settingRegistry } = settingStore();
    const [port, setPort] = useState<IExtensionSetting['port']>(9001);

    useEffect(() => {
      const updatePort = async () => {
        setPort(await settingStore.getPort());
      };
      const watch = async () => {
        const settings = await settingRegistry!.load('neopyter:labplugin');
        settings.changed.connect(updatePort);
      };
      watch();
      updatePort();
    }, []);
    return port;
  },
  updateSetting: async (setting: IExtensionSetting) => {
    const { settingRegistry } = settingStore.getState();
    const labSettings = await settingRegistry!.load('neopyter:labplugin');
    labSettings.set('mode', setting.mode);
    if (setting.mode === 'proxy') {
      labSettings.set('ip', setting.ip);
      labSettings.set('port', setting.port);
    } else {
      settingStore.setState({
        _ip: setting.ip,
        _port: setting.port
      });
    }
  }
};

export const settingStore = injectAction(createSet(createUse(settingState)), actions);
