import type { JupyterFrontEnd, JupyterFrontEndPlugin } from '@jupyterlab/application';
import type { CompletionHandler, CompletionProviderManager, CompletionTriggerKind, KernelCompleterProvider } from '@jupyterlab/completer';
import type { Notebook, NotebookPanel } from '@jupyterlab/notebook';
import type { Kernel } from '@jupyterlab/services';
import type { WindowedList } from '@jupyterlab/ui-components';
import type { ReadonlyPartialJSONObject } from '@lumino/coreutils';
import type { DockPanel } from '@lumino/widgets';
import type { Dispatcher } from './rpcService';
import type { CompletionItem, CompletionParams } from './types';
import { ILabShell, ILayoutRestorer } from '@jupyterlab/application';

import { ICompletionProviderManager } from '@jupyterlab/completer';

import { IDocumentManager } from '@jupyterlab/docmanager';
import { NotebookActions } from '@jupyterlab/notebook';
import * as R from 'remeda';
import { statusPageIcon } from './icons';
import logger from './logger';
import { StatusSidePanel } from './statusidepanel';
import { settingStore } from './store';

function convertCompleteSource(_item: CompletionHandler.ICompletionItem) {
  const item = _item as CompletionHandler.ICompletionItem & { [key: string]: any };
  return {
    label: item.label,
    type: item.type ?? item.options?.type,
    insertText: item.insertText,
    document: item.documentation,
    deprecated: item.deprecated,

    source: item?.source,
    sortText: item?.sortText,
  };
}

function triggerFocus(element: HTMLElement) {
  const eventType = 'onfocusin' in element ? 'focusin' : 'focus';
  const bubbles = 'onfocusin' in element;
  let event;

  if ('createEvent' in document) {
    event = document.createEvent('Event');
    event.initEvent(eventType, bubbles, true);
  }
  else if ('Event' in window) {
    event = new Event(eventType, { bubbles, cancelable: true });
  }

  element.focus();
  element.dispatchEvent(event as Event);
}

// Transfer Data
interface TCell {
  cell_type: string
  source: string
}

/**
 * Initialization data for the neopyter extension.
 */
const neopyterPlugin: JupyterFrontEndPlugin<void> = {
  id: 'neopyter:labplugin',
  description: 'A JupyterLab extension.',
  autoStart: true,
  requires: [ILabShell, IDocumentManager, ILayoutRestorer, ICompletionProviderManager],
  activate: (
    app: JupyterFrontEnd,
    labShell: ILabShell,
    docmanager: IDocumentManager,
    restorer: ILayoutRestorer,
    iCompletionProviderManager: ICompletionProviderManager,
  ) => {
    console.log('JupyterLab extension neopyter is activated!');

    const completionProviderManager = iCompletionProviderManager as CompletionProviderManager;
    const completerProviders = completionProviderManager.getProviders();

    const sidebar = new StatusSidePanel();
    sidebar.title.caption = 'Neopyter';
    sidebar.title.icon = statusPageIcon;
    app.shell.add(sidebar, 'right');

    if (restorer) {
      restorer.add(sidebar, '@neopyter/graphsidebar');
    }

    const getNotebookModel = (path?: string) => {
      let notebookPanel;
      if (path) {
        notebookPanel = docmanager.findWidget(path) as unknown as NotebookPanel;
      }
      let notebook = notebookPanel?.content as Notebook | undefined;
      if (!notebook) {
        const currentNotebookPanel = labShell.currentWidget as NotebookPanel;
        if (currentNotebookPanel?.isUntitled) {
          notebookPanel = currentNotebookPanel;
          notebook = notebookPanel.content;
        }
      }
      const sharedModel = notebook?.model?.sharedModel;

      if (!notebookPanel || !sharedModel || !notebook) {
        throw new Error(`Don't open ${path} and current don't select untitled ipynb`);
      }
      return {
        notebookPanel,
        notebook,
        sharedModel,
      };
    };

    const getCellModel = (path: string, cellIdx: number) => {
      const { notebook, sharedModel: sharedNotebookModel } = getNotebookModel(path);
      const sharedModel = sharedNotebookModel.getCell(cellIdx);
      return {
        notebook,
        sharedNotebookModel,
        sharedModel,
      };
    };

    const dispatcher: Dispatcher = {
      async getVersion() {
        const packageJson = await import('../package' + '.json');
        return packageJson.version;
      },
      echo: (message: string) => {
        const msg = `hello: ${message}`;
        return msg;
      },
      executeCommand: async (command: string, args?: ReadonlyPartialJSONObject) => {
        await app.commands.execute(command, args);
      },
    };
    const docmanagerDispatcher = {
      getCurrentNotebook: () => {
        const notebookPanel = labShell.currentWidget as NotebookPanel;
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
        }
        catch {
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
        // some hack code
        const { notebookPanel } = getNotebookModel(path);
        labShell.activateById(notebookPanel.id);
        notebookPanel.activate();
        const emitEvent = (node: HTMLElement) => {
          const event = new FocusEvent('focus', {
            bubbles: true,
            cancelable: true,
            view: window,
          });
          node.click();
          node.dispatchEvent(event);
          node.focus();
          triggerFocus(node);
        };
        // @ts-expect-error hack private property
        const dockPanel: DockPanel = labShell._dockPanel;

        for (const tabBar of dockPanel.tabBars()) {
          const tabIndex = tabBar.titles.findIndex((title) => {
            return title.owner === notebookPanel;
          });
          if (tabIndex >= 0) {
            const tab = tabBar.contentNode.children[tabIndex] as HTMLElement;
            emitEvent(tab);
            break;
          }
        }
        emitEvent(notebookPanel.node);
      },
      closeFile: async (path: string) => {
        return await docmanager.closeFile(path);
      },
      selectAbove: () => {
        const { notebook } = getNotebookModel();
        notebook && NotebookActions.selectBelow(notebook);
      },
      selectBelow: () => {
        const { notebook } = getNotebookModel();
        notebook && NotebookActions.selectBelow(notebook);
      },
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
              metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {},
            })),
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
          metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {},
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
      fullSync: (path: string, cells: TCell[]) => {
        const { notebook, sharedModel } = getNotebookModel(path);
        cells.forEach((cell, idx) => {
          const cellModel = sharedModel.getCell(idx);
          if (cellModel) {
            if (cell.cell_type === undefined || cellModel.cell_type === cell.cell_type) {
              cellModel.setSource(cell.source);
            }
            else {
              sharedModel.deleteCell(idx);
              sharedModel.insertCell(idx, {
                cell_type: cell.cell_type,
                source: cell.source,
                metadata: cellModel.getMetadata(),
              });
            }
          }
          else {
            sharedModel.insertCell(idx, {
              cell_type: cell.cell_type,
              source: cell.source,
              metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {},
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
        logger.info(
          `partialSync: current cell num:${sharedModel.cells.length}, from:${from}(include), to:${to}(include), update to cell num:${cells.length}`,
        );
        cells.forEach((cell, i) => {
          const idx = i + from;
          const cellModel = sharedModel.getCell(idx);
          if (idx <= to && cellModel) {
            if (cell.cell_type === undefined || cellModel.cell_type === cell.cell_type) {
              cellModel.setSource(cell.source);
            }
            else {
              sharedModel.deleteCell(idx);
              sharedModel.insertCell(idx, {
                cell_type: cell.cell_type,
                source: cell.source,
                metadata: cellModel.getMetadata(),
              });
            }
          }
          else {
            sharedModel.insertCell(idx, {
              cell_type: cell.cell_type,
              source: cell.source,
              metadata: notebook.notebookConfig.defaultCell === 'code' ? { trusted: true } : {},
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
        return await context?.save();
      },
      runSelectedCell: async (_path: string) => {
        return await app.commands.execute('notebook:run-cell');
      },
      runAllAbove: async (_path: string) => {
        return await app.commands.execute('notebook:run-all-above');
      },
      runAllBelow: async (_path: string) => {
        return await app.commands.execute('notebook:run-all-below');
      },
      runAll: async (_path: string) => {
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
      /**
       * @param path notebook file path
       */
      complete: async (path: string, { source, offset, cellIndex }: CompletionParams) => {
        const { notebookPanel, notebook } = getNotebookModel(path);

        if (cellIndex >= notebook.widgets.length) {
          console.warn('complete cellIndex not exists in notebook');
        }
        const cell = notebook.widgets[cellIndex];
        const completionItems: CompletionItem[] = [];
        for (const [completeSource, completer] of completerProviders) {
          try {
            const reply = await completer.fetch(
              {
                text: source,
                offset,
              },
              {
                widget: notebookPanel,
                editor: cell?.editor,
                session: notebookPanel.sessionContext.session,
              },
            );
            completionItems.push(...reply.items.map(item => ({
              ...convertCompleteSource(item),
              source: completer.identifier,

            })));
          }
          catch (e) {
            logger.error(`Completer [${completeSource}] error, please your other jupyterlab extensions:`, e);
          }
        }
        logger.info(completionItems);
        return completionItems;
      },
      /**
       * @param path notebook file path
       */
      reconciliatorComplete: async (path: string, { source, offset, cellIndex, trigger }: CompletionParams) => {
        const { notebookPanel, notebook } = getNotebookModel(path);

        console.log(completionProviderManager);
        console.log(notebookPanel.id, notebook.id);

        if (cellIndex >= notebook.widgets.length) {
          logger.error(`Cell ${cellIndex} out of notebook range`);
          return [];
        }

        /**
         * editor: `os.<cursor>`
         * input:
         * {
         *  "text": "os.",
         *  "offset": 3,
         *  "mimeType": "text/x-ipython"
         * }
         */

        /**
         * editor: `foo(os.<cursor>, 1)`
         * input:
         * {
         *  "text": "foo(os., 1)",
         *  "offset": 7,
         *  "mimeType": "text/x-ipython"
         * }
         */
        const requestCompletion = async (request: CompletionHandler.IRequest, trigger?: CompletionTriggerKind): Promise<CompletionHandler.ICompletionItemsReply> => {
        // @ts-expect-error use private fields
          const handler: CompletionHandler = completionProviderManager._panelHandlers.get(notebookPanel.id);
          // @ts-expect-error use private fields
          return await handler._reconciliator.fetch(request, trigger);
        };

        try {
          const reply = await requestCompletion({ text: source, offset }, trigger);
          if (!reply) {
            logger.info('complete return null: ', { source, offset, trigger });
            return [];
          }
          logger.info('complete return', { source, offset, trigger }, reply.items);
          const completionItems = reply.items.map(convertCompleteSource);
          return completionItems;
        }
        catch (e) {
          logger.error(`complete failed:`, e);
        }
        return [];
      },
      kernelComplete: async (path: string, source: string, offset: number) => {
        const { notebookPanel } = getNotebookModel(path);
        const kernelCompleteSource = 'CompletionProvider:kernel';

        const kernelCompleterProvider = completerProviders.get(kernelCompleteSource) as KernelCompleterProvider;
        const reply = await kernelCompleterProvider.fetch(
          {
            text: source,
            offset,
          },
          {
            widget: notebookPanel,
            session: notebookPanel.sessionContext.session,
          },
        );
        const completionItems = reply.items.map(convertCompleteSource);
        logger.info(completionItems);

        return completionItems;
      },
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
            metadata: sharedModel.getMetadata(),
          });
        }
      },
    };

    Object.assign(dispatcher, docmanagerDispatcher);
    Object.assign(dispatcher, notebookDispatcher);
    Object.assign(dispatcher, cellDispatcher);
    settingStore.startConnection(dispatcher);
  },
};

export default [neopyterPlugin];
