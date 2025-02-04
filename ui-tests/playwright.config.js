import process from 'node:process';
/**
 * Configuration for Playwright using default from @jupyterlab/galata
 */
import baseConfig from '@jupyterlab/galata/lib/playwright-config.js';

export default {
  ...baseConfig,
  webServer: {
    command: 'pnpm start',
    url: 'http://localhost:8888/lab',
    timeout: 120 * 1000,
    reuseExistingServer: !process.env.CI,
  },
};
