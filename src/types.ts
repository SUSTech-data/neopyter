import type { CompletionHandler } from '@jupyterlab/completer';

export enum WorkMode {
  direct = 'direct',
  proxy = 'proxy',
}
export enum LogLevel {
  info = 'info',
  warn = 'warn',
  debug = 'debug',
  error = 'error',
}

export interface CompletionParams {
  /** code before cursor, provided by nvim-cmp */
  source: string
  /** the cell index of cursor */
  cellIndex: number
  /** offset of cursor in source, provided by nvim-cmp */
  offset: number
}

export type CompletionItem = CompletionHandler.ICompletionItem & {
  source: string
};
