import { Kernel, ServerConnection } from '@jupyterlab/services';
import { URLExt } from '@jupyterlab/coreutils';
import { JupyterFrontEnd, JupyterFrontEndPlugin } from '@jupyterlab/application';
import { INotebookTracker, NotebookActions } from '@jupyterlab/notebook';
import { RpcServer, Dispatcher } from './rpcServer';
import { WebsocketTransport } from './transport';
import { IDocumentManager } from '@jupyterlab/docmanager';

/**
 * Initialization data for the neopyter extension. */
const neopyterPlugin: JupyterFrontEndPlugin<void> = {
  id: 'neopyter',
  description: 'A JupyterLab extension.',
  autoStart: true,
  requires: [IDocumentManager, INotebookTracker],
  activate: (app: JupyterFrontEnd, docmanager: IDocumentManager, nbtracker: INotebookTracker) => {
    console.log('JupyterLab extension noejupy is activated!');

    const settings = ServerConnection.makeSettings();
    const url = URLExt.join(settings.wsUrl, 'neopyter', 'channel');
    const currentNotebook = () => {
      return nbtracker.currentWidget?.content;
    };

    const dispatcher: Dispatcher = {
      echo: (message: string) => {
        const msg = `hello: ${message}`;
        return msg;
      },
      isFileOpen: (path: string) => {
        return !!docmanager.findWidget(path);
      },
      isFileExist: async (path: string) => {
        return !!(await docmanager.services.contents.get(path));
      },
      createNew: (path: string, widgetName?: string, kernel?: Kernel.IModel) => {
        return docmanager.createNew(path, widgetName, kernel);
      },
      openFile: (path: string) => {
        return !!docmanager.open(path);
      },
      openOrReveal: (path: string) => {
        return !!docmanager.openOrReveal(path);
      },
      closeFile: async (path: string) => {
        return await docmanager.closeFile(path);
      },
      selectAbove: () => {
        const notebook = currentNotebook();
        notebook && NotebookActions.selectBelow(notebook);
      },
      selectBelow: () => {
        const notebook = currentNotebook();
        notebook && NotebookActions.selectBelow(notebook);
      }
    };
    const server = new RpcServer(dispatcher);
    server.start(WebsocketTransport, url);
  }
};

export default [neopyterPlugin];
