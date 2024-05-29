import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { ReactWidget, SidePanel } from '@jupyterlab/ui-components';
import { ISettingRegistry } from '@jupyterlab/settingregistry';
import React, { useCallback, useEffect, useState } from 'react';
import { withTheme } from '@rjsf/core';
import { Theme as AntDTheme } from '@rjsf/antd';
import { RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { IExtensionSetting, settingStore } from './store';
import { Button, Tooltip } from 'antd';

const Form = withTheme(AntDTheme);

const SettingForm = () => {
  const [schema, setSchema] = useState<RJSFSchema>(undefined!);
  const mode = settingStore.useMode();
  const ip = settingStore.useIp();
  const port = settingStore.usePort();
  useEffect(() => {
    const updateSchema = async () => {
      const settingSchema = await import('../schema/labplugin' + '.json');
      setSchema(settingSchema);
    };
    updateSchema();
  }, []);

  const onSubmit = useCallback(async ({ formData }: { formData: IExtensionSetting }) => {
    await settingStore.updateSetting(formData);
  }, []);

  return (
    <>
      {schema ? (
        <Form schema={schema} validator={validator} formData={{ mode, ip, port }} onSubmit={onSubmit as any}>
          <Tooltip title="Please reload web page after saved">
            <Button type="primary" htmlType="submit" style={{ left: '50%', position: 'relative' }}>
              Save
            </Button>
          </Tooltip>
        </Form>
      ) : undefined}
    </>
  );
};

export class StatusSidePanel extends SidePanel {
  constructor(private settingRegistry: ISettingRegistry) {
    super();
    this.id = 'neopyter-status-sidepanel';
    const widget = ReactWidget.create(<SettingForm />);
    widget.title.label = 'Neopyter Settings';
    this.content.addWidget(widget);
    this.watchSettings();
  }

  async watchSettings() {
    const updateSettings = async (settings: ISettingRegistry.ISettings) => {
      const config = settings.composite as unknown as IExtensionSetting;
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
      console.log('update settings:', await response.json());
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
