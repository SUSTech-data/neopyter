import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { SidePanel } from '@jupyterlab/ui-components';
import { ISettingRegistry } from '@jupyterlab/settingregistry';

interface IConfig {
  port?: number;
  ip?: string;
}

export class StatusSidePanel extends SidePanel {
  constructor(private settingRegistry: ISettingRegistry) {
    super();
    this.id = 'neopyter-status-sidepanel';
    this.watchSettings();
  }
  async updatePanel() {
    const settings = ServerConnection.makeSettings();
    const url = URLExt.join(settings.baseUrl, 'neopyter', 'get_server_info');
    const response = await fetch(url);

    this.content.node.textContent = '';
    if (!response.ok) {
      const p = document.createElement('p');
      this.content.node.appendChild(p);
      p.textContent = 'Access API failed';
      return;
    }
    const { code, message, data } = await response.json();
    if (code !== 0) {
      const p = document.createElement('p');
      this.content.node.appendChild(p);
      p.textContent = message;
      return;
    }
    for (const addr of data.addrs) {
      const p = document.createElement('p');
      this.content.node.appendChild(p);
      p.textContent = addr;
    }
  }

  async watchSettings() {
    let config: IConfig = {};
    const updateSettings = async (settings: ISettingRegistry.ISettings) => {
      config = settings.composite as IConfig;
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
      this.updatePanel();
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
