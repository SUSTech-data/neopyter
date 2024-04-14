import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { SidePanel } from '@jupyterlab/ui-components';
import { ISettingRegistry } from '@jupyterlab/settingregistry';
import { IConfig } from './settings';

export class StatusSidePanel extends SidePanel {
  constructor(private settingRegistry: ISettingRegistry) {
    super();
    this.id = 'neopyter-status-sidepanel';
    this.watchSettings();
  }
  async updatePanel() {
    const settings = (await this.settingRegistry.load('neopyter:labplugin')).composite as unknown as IConfig;
    this.content.node.textContent = '';
    {
      const h2 = document.createElement('h2');
      this.content.node.appendChild(h2);
      h2.textContent = `Work mode: ${settings.mode}`;
    }
    if (settings.mode === 'proxy') {
      const serverSettings = ServerConnection.makeSettings();
      const url = URLExt.join(serverSettings.baseUrl, 'neopyter', 'get_server_info');
      const response = await fetch(url);

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
    } else {
      {
        const p = document.createElement('p');
        this.content.node.appendChild(p);
        p.textContent = `IP: ${settings.ip}`;
      }

      {
        const p = document.createElement('p');
        this.content.node.appendChild(p);
        p.textContent = `port: ${settings.port}`;
      }
    }
  }

  async watchSettings() {
    const updateSettings = async (settings: ISettingRegistry.ISettings) => {
      const config = settings.composite as unknown as IConfig;
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
