import { IDocumentManager } from '@jupyterlab/docmanager';
import { IDisposable } from '@lumino/disposable';
import { Kernel } from '@jupyterlab/services';

type OmitIDisposable<T> = { [key in Exclude<keyof T, keyof IDisposable>]: T[key] };

type FunctionKeys<T> = { [key in keyof T]: T[key] extends (...args: any[]) => any ? key : never }[keyof T];

// type PickFunction<T> = { [key in FunctionKeys<T>]: T[key] };

type TokenDispatcher<T extends IDisposable> = {
  [key in FunctionKeys<OmitIDisposable<T>>]: T[key] extends (...args: any[]) => Promise<any>
    ? (...args: any[]) => Promise<unknown>
    : (...args: any[]) => unknown;
};

// type VV = TokenDispatcher<IDocumentManager>;

// https://jupyterlab.readthedocs.io/en/stable/api/classes/docmanager.DocumentManager-1.html
// TODO:reflection generate dispatcher
export const genDocManagerDispatcher = (docmanager: IDocumentManager): Partial<TokenDispatcher<IDocumentManager>> => {
  return {
    closeAll: async () => {
      docmanager.closeAll();
    },
    closeFile: async (path: string) => {
      await docmanager.closeFile(path);
    },
    copy: async (fromFile: string, toDir: string) => {
      return await docmanager.copy(fromFile, toDir);
    },
    createNew: (path: string, widgetName?: string, kernel?: Kernel.IModel) => {
      return docmanager.createNew(path, widgetName, kernel);
    },
    deleteFile: async (path: string) => {
      return await docmanager.deleteFile(path);
    },
    duplicate: async (path: string) => {
      const model = await docmanager.duplicate(path);
      return model.path;
    },
    findWidget: (path: string) => {
      return docmanager.findWidget(path);
    },
    newUntitled: async (opts: { path?: string; type?: 'notebook' | 'file' }) => {
      const model = await docmanager.newUntitled(opts);
      return model.path;
    },
    open
  };
};
