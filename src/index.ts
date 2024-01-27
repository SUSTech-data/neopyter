import { Kernel, ServerConnection } from '@jupyterlab/services';
import { URLExt } from '@jupyterlab/coreutils';
import { ReadonlyPartialJSONObject } from '@lumino/coreutils';
import { ILayoutRestorer, JupyterFrontEnd, JupyterFrontEndPlugin } from '@jupyterlab/application';
import { Notebook, INotebookTracker, NotebookActions, NotebookPanel } from '@jupyterlab/notebook';
import { IDocumentManager } from '@jupyterlab/docmanager';
import { ISettingRegistry } from '@jupyterlab/settingregistry';
import { ICompletionProviderManager, KernelCompleterProvider, CompletionProviderManager } from '@jupyterlab/completer';

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
  id: 'neopyter:labplugin',
  description: 'A JupyterLab extension.',
  autoStart: true,
  requires: [IDocumentManager, INotebookTracker, ILayoutRestorer, ISettingRegistry, ICompletionProviderManager],
  activate: (
    app: JupyterFrontEnd,
    docmanager: IDocumentManager,
    nbtracker: INotebookTracker,
    restorer: ILayoutRestorer,
    settingRegistry: ISettingRegistry,
    _completionProviderManager: ICompletionProviderManager
  ) => {
    const completionProviderManager = _completionProviderManager as CompletionProviderManager;
    const providers = completionProviderManager.getProviders();
    console.log('JupyterLab extension neopyter is activated!');
    console.log('provider', completionProviderManager.getProviders());
    const kernelCompleterProvider = providers.get('CompletionProvider:kernel') as KernelCompleterProvider;
    // completionProviderManager.updateCompleter

    const sidebar = new StatusSidePanel(settingRegistry);
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
      let notebookPanel = docmanager.findWidget(path) as unknown as NotebookPanel;
      let notebook = notebookPanel?.content as Notebook | undefined;
      if (!notebook) {
        if (nbtracker.currentWidget?.isUntitled) {
          notebookPanel = nbtracker.currentWidget;
          notebook = nbtracker.currentWidget.content;
        }
      }
      const sharedModel = notebook?.model?.sharedModel;

      if (!notebookPanel || !sharedModel || !notebook) {
        throw `Don't open ${path} and current don't select untitled ipynb`;
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
        app.shell.activateById(notebookPanel.id);
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
        // notebook.setAc
        notebook.activeCellIndex = index;
      },
      scrollToItem: (path: string, index: number, align?: WindowedList.ScrollToAlign, margin?: number) => {
        const { notebook } = getNotebookModel(path);
        notebook.scrollToItem(index, align, margin);
      },
      fullSync: (path: string, cells: TCell[]) => {
        const { notebook, sharedModel } = getNotebookModel(path);
        cells.forEach((cell, idx) => {
          const cellModel = sharedModel.getCell(idx);
          if (cellModel) {
            if (cell.cell_type === undefined || cellModel.cell_type === cell.cell_type) {
              cellModel.setSource(cell.source);
            } else {
              sharedModel.deleteCell(idx);
              sharedModel.insertCell(idx, {
                cell_type: cell.cell_type,
                source: cell.source,
                metadata: cellModel.getMetadata()
              });
            }
          } else {
            sharedModel.insertCell(idx, {
              cell_type: cell.cell_type,
              source: cell.source,
              metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {}
            });
          }
        });
        while (cells.length < sharedModel.cells.length) {
          sharedModel.deleteCell(sharedModel.cells.length - 1);
        }
      },
      partialSync: (path: string, from: number, to: number, cells: TCell[]) => {
        // replace cells from(include)-to(include) to new cells
        const { notebook, sharedModel } = getNotebookModel(path);
        console.log(
          `partialSync: current cell num:${sharedModel.cells.length}, from:${from}(include), to:${to}(include), update to cell num:${cells.length}`
        );
        cells.forEach((cell, i) => {
          const idx = i + from;
          const cellModel = sharedModel.getCell(idx);
          if (idx <= to && cellModel) {
            if (cell.cell_type === undefined || cellModel.cell_type === cell.cell_type) {
              cellModel.setSource(cell.source);
            } else {
              sharedModel.deleteCell(idx);
              sharedModel.insertCell(idx, {
                cell_type: cell.cell_type,
                source: cell.source,
                metadata: cellModel.getMetadata()
              });
            }
          } else {
            sharedModel.insertCell(idx, {
              cell_type: cell.cell_type,
              source: cell.source,
              metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {}
            });
          }
        });
        while (to - from + 1 > cells.length) {
          sharedModel.deleteCell(to);
          to = to - 1;
        }
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
      },
      setMode: (path: string, mode: 'command' | 'edit') => {
        const { notebookPanel } = getNotebookModel(path);
        notebookPanel.content.mode = mode;
      },
      // kernelComplete: async (path: string, index: number, row: number, col: number) => {
      kernelComplete: async (path: string, source: string, offset: number) => {
        const { notebookPanel } = getNotebookModel(path);

        console.log('kernelComplete:', source, offset);
        const completionItems = await kernelCompleterProvider.fetch(
          {
            text: source,
            offset: offset
          },
          {
            widget: notebookPanel,
            session: notebookPanel.sessionContext.session
          }
        );
        console.log(completionItems);
        return completionItems.items;
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
