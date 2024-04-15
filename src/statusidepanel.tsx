import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { ReactWidget, SidePanel } from '@jupyterlab/ui-components';
import { ISettingRegistry } from '@jupyterlab/settingregistry';
import React, { useEffect, useCallback } from 'react';
import { withTheme } from '@rjsf/core';
import { Theme as AntDTheme } from '@rjsf/antd';
import { RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { IExtensionSetting, settingStore } from './store';

const Form = withTheme(AntDTheme);

const schema: RJSFSchema = {
  title: 'Neopyter',
  description: 'A JupyterLab extension. Integrate JupyterLab and Neovim',
  definitions: {
    mode: {
      enum: ['proxy', 'direct']
    },
    ip: {
      type: 'string',
      format: 'ipv4'
    },
    port: {
      type: 'number'
    }
  },
  properties: {
    mode: {
      title: 'Neopyter work mode',
      description:
        'Different work mode determine different methods of communication arcitecture. The `proxy` mode will communicate through jupyter server, while the `direct` mode will communicate directly with nvim',
      $ref: '#/definitions/mode',
      default: 'direct'
    },
    ip: {
      title: 'IP',
      description:
        'For `proxy` mode, this is the IP of the host where jupyter server is located; For `direct` mode, this is the IP of the host where nvim is located ',
      $ref: '#/definitions/ip',
      default: '127.0.0.1'
    },
    port: {
      title: 'Port',
      $ref: '#/definitions/port',
      default: 9001
    }
  },
  required: ['mode', 'ip', 'port'],
  additionalProperties: false,
  type: 'object'
};

const SettingForm = () => {
  const settingRegistry = settingStore.useSettingRegistry();
  const mode = settingStore.useMode();
  const ip = settingStore.useIp();
  const port = settingStore.usePort();
  useEffect(() => {
    const updateSchema = async () => {
      const labSettings = await settingRegistry!.load('neopyter:labplugin');
      console.log(labSettings.schema);
    };
    updateSchema();
  }, []);

  const onSubmit = useCallback(async ({ formData }: { formData: IExtensionSetting }) => {
    await settingStore.updateSetting(formData);
  }, []);

  return (
    <Form schema={schema} validator={validator} formData={{ mode, ip, port }} onSubmit={onSubmit as any}>
      <button style={{ width: '100px', height: '40px' }} type="submit">
        <span>Save</span>
      </button>
    </Form>
  );
};

export class StatusSidePanel extends SidePanel {
  constructor(private settingRegistry: ISettingRegistry) {
    super();
    this.id = 'neopyter-status-sidepanel';
    const widget = ReactWidget.create(<SettingForm />);
    this.content.addWidget(widget);
    this.header.title.label = 'Setting';
    this.watchSettings();
  }

  async watchSettings() {
    const updateSettings = async (settings: ISettingRegistry.ISettings) => {
      const config = settings.composite as unknown as IExtensionSetting;
      console.log('updateSettings', config);
      const connectSettings = ServerConnection.makeSettings();
      const baseUrl = connectSettings.baseUrl;
      const url = URLExt.join(baseUrl, 'neopyter', 'update_settings');
      const response = await ServerConnection.makeRequest(
        url,
        {
          method: 'POST',
          body: JSON.stringify(config)
        },
        connectSettings
      );
      console.log(await response.json());
    };
    // Fetch the initial state of the settings.
    const settings = await this.settingRegistry.load('neopyter:labplugin');
    settings.changed.connect(() => {
      updateSettings(settings);
    });
    updateSettings(settings);
  }
  async restartServer() {}
}
