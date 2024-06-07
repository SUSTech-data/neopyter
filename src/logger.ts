import { settingStore } from './store';
import { LogLevel } from './types';

export const info = (...data: any[]) => {
  if (settingStore.getState().loglevel === LogLevel.info) {
    console.log(...data);
  }
};

export const warn = (...data: any[]) => {
  const level = settingStore.getState().loglevel;
  if (level === LogLevel.warn || level === LogLevel.info) {
    console.warn(...data);
  }
};

export const debug = (...data: any[]) => {
  const level = settingStore.getState().loglevel;
  if (level === LogLevel.warn || level === LogLevel.info || level === LogLevel.debug) {
    console.debug(...data);
  }
};

export const error = (...data: any[]) => {
  console.error(...data);
};
export default {
  info,
  warn,
  debug,
  error
} as const;
