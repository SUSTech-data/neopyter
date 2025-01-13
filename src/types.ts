import type { CompletionHandler, CompletionTriggerKind } from '@jupyterlab/completer';

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
  /**
   * cell code
   */
  source: string
  /**
   * the cell index of cursor
   */
  cellIndex: number
  /**
   * offset of cursor in source, 0-based
   */
  offset: number
  /**
   * completion kind
   */
  trigger: CompletionTriggerKind
  /**
   * The cursor line number.
   */
  readonly line: number
  /**
   * The cursor column number.
   */
  readonly column: number
}

export type CompletionItem = CompletionHandler.ICompletionItem & {
  source: string
};
