import { URLExt } from '@jupyterlab/coreutils';
import { ServerConnection } from '@jupyterlab/services';
import { SidePanel } from '@jupyterlab/ui-components';
export class StatusSidePanel extends SidePanel {
  constructor() {
    super();
    this.id = 'neopyter-status-sidepanel';
    const settings = ServerConnection.makeSettings();
    const url = URLExt.join(settings.baseUrl, 'neopyter', 'tcp_server_info');
    setTimeout(async () => {
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
      for (const host of data.hosts) {
        const p = document.createElement('p');
        this.content.node.appendChild(p);
        p.textContent = `${host}:${data.port}`;
      }
    }, 1000);
  }
}
