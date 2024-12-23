import { LogLevel } from './types';

let info = console.info.bind(window.console);
let debug = console.debug.bind(window.console);
let warn = console.warn.bind(window.console);
const error = console.error.bind(window.console);

function setLevel(loglevel: LogLevel) {
  if (loglevel === LogLevel.info) {
    info = console.info.bind(window.console);
  }
  else {
    info = () => {};

    if (loglevel === LogLevel.debug) {
      debug = console.debug.bind(window.console);
    }
    else {
      debug = () => {};
      if (loglevel === LogLevel.warn) {
        warn = console.warn.bind(window.console);
      }
      else {
        warn = () => {};
      }
    }
  }
}

export default {
  info,
  warn,
  debug,
  error,
  setLevel,
} as const;
