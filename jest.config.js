import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import jestJupyterLab from '@jupyterlab/testutils/lib/jest-config.js';

const esModules = ['@codemirror', '@jupyter/ydoc', '@jupyterlab/', 'lib0', 'nanoid', 'vscode-ws-jsonrpc', 'y-protocols', 'y-websocket', 'yjs'].join(
  '|',
);

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const baseConfig = jestJupyterLab(__dirname);

export default {
  ...baseConfig,
  automock: false,
  collectCoverageFrom: ['src/**/*.{ts,tsx}', '!src/**/*.d.ts', '!src/**/.ipynb_checkpoints/*'],
  coverageReporters: ['lcov', 'text'],
  testRegex: 'src/.*/.*.spec.ts[x]?$',
  setupFiles: ['<rootDir>/jest.setup.js', ...baseConfig.setupFiles],
  transform: {
    // '^.+\\.[tj]sx?$' to process ts,js,tsx,jsx with `ts-jest`
    // '^.+\\.m?[tj]sx?$' to process ts,js,tsx,jsx,mts,mjs,mtsx,mjsx with `ts-jest`
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        tsconfig: 'tsconfig.test.json',
      },
    ],
  },
  transformIgnorePatterns: [`/node_modules/(?!${esModules}).+`],
};
