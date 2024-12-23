import type { RJSFSchema } from '@rjsf/utils';
import type { IExtensionSetting } from './store';
import { ReactWidget, SidePanel } from '@jupyterlab/ui-components';
import { Theme as AntDTheme } from '@rjsf/antd';
import { withTheme } from '@rjsf/core';
import validator from '@rjsf/validator-ajv8';
import { Button, Tooltip } from 'antd';
import React, { useCallback, useEffect, useState } from 'react';
import logger from './logger';
import { settingStore } from './store';

const Form = withTheme(AntDTheme);

function SettingForm() {
  const [schema, setSchema] = useState<RJSFSchema>(undefined!);
  const settings = settingStore();

  useEffect(() => {
    const updateSchema = async () => {
      const settingSchema = await import('../schema/labplugin' + '.json');
      setSchema(settingSchema);
    };
    updateSchema();

    logger.setLevel(settingStore.getState().loglevel);
    return settingStore.subscribe(({ loglevel }) => logger.setLevel(loglevel));
  }, []);

  const onSubmit = useCallback(async ({ formData }: { formData: IExtensionSetting }) => {
    logger.info('save settings: ', JSON.stringify(formData));
    settingStore.updateSettings(formData);
  }, []);

  return (
    <>
      {schema
        ? (
            <Form schema={schema} validator={validator} formData={settings} onSubmit={onSubmit as any}>
              <Tooltip title="Please reload web page after saved">
                <Button type="primary" htmlType="submit" style={{ left: '50%', position: 'relative' }}>
                  Save
                </Button>
              </Tooltip>
            </Form>
          )
        : undefined}
    </>
  );
}

export class StatusSidePanel extends SidePanel {
  constructor() {
    super();
    this.id = 'neopyter-status-sidepanel';
    const widget = ReactWidget.create(<SettingForm />);
    widget.title.label = 'Neopyter Settings';
    this.content.addWidget(widget);
  }
}
