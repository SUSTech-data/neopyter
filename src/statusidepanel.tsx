import { ReactWidget, SidePanel } from '@jupyterlab/ui-components';
import React, { useCallback, useEffect, useState } from 'react';
import { withTheme } from '@rjsf/core';
import { Theme as AntDTheme } from '@rjsf/antd';
import { RJSFSchema } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import { Button, Tooltip } from 'antd';
import { IExtensionSetting, settingStore } from './store';
import logger from './logger';

const Form = withTheme(AntDTheme);

const SettingForm = () => {
  const [schema, setSchema] = useState<RJSFSchema>(undefined!);
  const settings = settingStore();
  useEffect(() => {
    const updateSchema = async () => {
      const settingSchema = await import('../schema/labplugin' + '.json');
      setSchema(settingSchema);
    };
    updateSchema();
  }, []);

  const onSubmit = useCallback(async ({ formData }: { formData: IExtensionSetting }) => {
    logger.info('save settings: ', JSON.stringify(formData));
    settingStore.updateSettings(formData);
  }, []);

  return (
    <>
      {schema ? (
        <Form schema={schema} validator={validator} formData={settings} onSubmit={onSubmit as any}>
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
  constructor() {
    super();
    this.id = 'neopyter-status-sidepanel';
    const widget = ReactWidget.create(<SettingForm />);
    widget.title.label = 'Neopyter Settings';
    this.content.addWidget(widget);
  }
}
