import { Kernel, ServerConnection } from '@jupyterlab/services';
import { URLExt } from '@jupyterlab/coreutils';
import { ReadonlyPartialJSONObject } from '@lumino/coreutils';
import { ILayoutRestorer, JupyterFrontEnd, JupyterFrontEndPlugin } from '@jupyterlab/application';
import { Notebook, INotebookTracker, NotebookActions, NotebookPanel } from '@jupyterlab/notebook';
import { IDocumentManager } from '@jupyterlab/docmanager';
import * as R from 'remeda';

import { RpcServer, Dispatcher } from './rpcServer';
import { WebsocketTransport } from './transport';
import { StatusSidePanel } from './statusidepanel';
import { statusPageIcon } from './icons';
import { WindowedList } from '@jupyterlab/ui-components';

// Transfer Data
type TCell = {
  cell_type: string;
  source: string;
};

/**
 * Initialization data for the neopyter extension. */
const neopyterPlugin: JupyterFrontEndPlugin<void> = {
  id: 'neopyter',
  description: 'A JupyterLab extension.',
  autoStart: true,
  requires: [IDocumentManager, INotebookTracker, ILayoutRestorer],
  activate: (
    app: JupyterFrontEnd,
    docmanager: IDocumentManager,
    nbtracker: INotebookTracker,
    restorer: ILayoutRestorer
  ) => {
    console.log('JupyterLab extension neopyter is activated!');

    const sidebar = new StatusSidePanel();
    sidebar.title.caption = 'Neopyter';
    sidebar.title.icon = statusPageIcon;
    app.shell.add(sidebar, 'right');

    if (restorer) {
      restorer.add(sidebar, '@neopyter/graphsidebar');
    }

    const settings = ServerConnection.makeSettings();
    const url = URLExt.join(settings.wsUrl, 'neopyter', 'channel');
    const getCurrentNotebook = () => {
      const widget = nbtracker.currentWidget as NotebookPanel;
      app.shell.activateById(widget.id);
      return widget?.content;
    };
    const getNotebookModel = (path: string) => {
      let notebookPanel = docmanager.findWidget(path) as NotebookPanel;
      let notebook = notebookPanel?.content as Notebook | undefined;
      if (!notebook) {
        if (nbtracker.currentWidget?.isUntitled) {
          notebookPanel = nbtracker.currentWidget;
          notebook = nbtracker.currentWidget.content;
        }
      }
      const sharedModel = notebook?.model?.sharedModel;

      if (!notebookPanel || !sharedModel || !notebook) {
        throw `Can't find ${path} and current don't select untitled ipynb`;
      }
      return {
        notebookPanel,
        notebook,
        sharedModel
      };
    };

    const getCellModel = (path: string, cellIdx: number) => {
      const { notebook, sharedModel: sharedNotebookModel } = getNotebookModel(path);
      const sharedModel = sharedNotebookModel.getCell(cellIdx);
      return {
        notebook,
        sharedNotebookModel,
        sharedModel
      };
    };

    const dispatcher: Dispatcher = {
      echo: (message: string) => {
        const msg = `hello: ${message}`;
        return msg;
      },
      executeCommand: async (command: string, args?: ReadonlyPartialJSONObject) => {
        await app.commands.execute(command, args);
      }
    };
    const docmanagerDispatcher = {
      getCurrentNotebook: () => {
        const notebookPanel = nbtracker.currentWidget;
        if (notebookPanel) {
          const context = docmanager.contextForWidget(notebookPanel);
          return context?.localPath;
        }
      },
      isFileOpen: (path: string) => {
        return !!docmanager.findWidget(path);
      },
      isFileExist: async (path: string) => {
        try {
          return !!(await docmanager.services.contents.get(path));
        } catch (e) {
          if ((e as { response: Response }).response.status !== 404) {
            throw e;
          }
          return false;
        }
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
      activateNotebook: (path: string) => {
        const { notebookPanel } = getNotebookModel(path);
        return notebookPanel.activate();
      },
      closeFile: async (path: string) => {
        return await docmanager.closeFile(path);
      },
      selectAbove: () => {
        const notebook = getCurrentNotebook();
        notebook && NotebookActions.selectBelow(notebook);
      },
      selectBelow: () => {
        const notebook = getCurrentNotebook();
        notebook && NotebookActions.selectBelow(notebook);
      }
    };

    const notebookDispatcher = {
      getCellNum: (path: string) => {
        return getNotebookModel(path).sharedModel.cells.length;
      },
      setCellNum: (path: string, num: number) => {
        const { notebook, sharedModel } = getNotebookModel(path);
        const currentNum = sharedModel.cells.length;
        if (num > currentNum) {
          sharedModel.insertCells(
            currentNum,
            R.range(0, num - currentNum).map(() => ({
              cell_type: notebook.notebookConfig.defaultCell,
              metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {}
            }))
          );
          return;
        }
        while (num < sharedModel.cells.length) {
          sharedModel.deleteCell(sharedModel.cells.length - 1);
        }
      },

      getCell: (path: string, index: number) => {
        const { sharedModel } = getCellModel(path, index);
        return sharedModel.toJSON();
      },

      deleteCell: (path: string, index: number) => {
        return getNotebookModel(path).sharedModel.deleteCell(index);
      },
      insertCell: (path: string, index: number) => {
        const { notebook, sharedModel } = getNotebookModel(path);
        return sharedModel.insertCell(index, {
          cell_type: notebook.notebookConfig.defaultCell,
          metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {}
        });
      },
      activateCell: (path: string, index: number) => {
        const { notebook } = getNotebookModel(path);
        notebook.activeCellIndex = index;
      },
      scrollToItem: (path: string, index: number, align?: WindowedList.ScrollToAlign, margin?: number) => {
        const { notebook } = getNotebookModel(path);
        notebook.scrollToItem(index, align, margin);
      },
      syncCells: (path: string, from: number, cells: TCell[]) => {
        const { notebook, sharedModel: sharedNotebookModel } = getNotebookModel(path);
        cells.forEach((cell, idx) => {
          const index = from + idx;
          const cellModel = sharedNotebookModel.getCell(index);
          if (cellModel) {
            if (cell.cell_type === undefined || cellModel.cell_type === cell.cell_type) {
              cellModel.setSource(cell.source);
            } else {
              sharedNotebookModel.deleteCell(idx);
              sharedNotebookModel.insertCell(idx, {
                cell_type: cell.cell_type,
                source: cell.source,
                metadata: cellModel.getMetadata()
              });
            }
            return;
          }
          sharedNotebookModel.insertCell(index, {
            cell_type: cell.cell_type,
            source: cell.source,
            metadata:
              notebook.notebookConfig.defaultCell === 'code'
                ? {
                    // This is an empty cell created by user, thus is trusted
                    trusted: true
                  }
                : {}
          });
        });
      },
      save: async (path: string) => {
        const { notebookPanel } = getNotebookModel(path);
        const context = docmanager.contextForWidget(notebookPanel);
        context?.path;
        return await context?.save();
      },
      runSelectedCell: async (path: string) => {
        return await app.commands.execute('notebook:run-cell');
      },
      runAllAbove: async (path: string) => {
        return await app.commands.execute('notebook:run-all-above');
      },
      runAllBelow: async (path: string) => {
        return await app.commands.execute('notebook:run-all-below');
      },
      runAll: async (path: string) => {
        return await app.commands.execute('notebook:run-all-cells');
      },
      restartKernel: async (path: string) => {
        const { notebookPanel } = getNotebookModel(path);
        return await notebookPanel.sessionContext.restartKernel();
      },
      restartRunAll: async (path: string) => {
        const { notebookPanel } = getNotebookModel(path);
        await notebookPanel.sessionContext.restartKernel();
        return await app.commands.execute('notebook:run-all-cells');
      }
    };
    const cellDispatcher = {
      setCellSource: (path: string, cellIdx: number, source: string) => {
        const { sharedModel } = getCellModel(path, cellIdx);
        sharedModel.setSource(source);
      },
      setCellType: (path: string, cellIdx: number, type: string) => {
        const { sharedNotebookModel, sharedModel } = getCellModel(path, cellIdx);
        if (sharedModel.cell_type !== type) {
          sharedNotebookModel.deleteCell(cellIdx);
          sharedNotebookModel.insertCell(cellIdx, {
            cell_type: type,
            source: sharedModel.getSource(),
            metadata: sharedModel.getMetadata()
          });
        }
      }
    };

    Object.assign(dispatcher, docmanagerDispatcher);
    Object.assign(dispatcher, notebookDispatcher);
    Object.assign(dispatcher, cellDispatcher);
    const server = new RpcServer(dispatcher);
    server.start(WebsocketTransport, url);
  }
};

export default [neopyterPlugin];
