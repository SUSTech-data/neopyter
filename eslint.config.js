import antfu from '@antfu/eslint-config';

export default antfu({
  stylistic: {
    indent: 2,
    quotes: 'single',
  },
  toml: false,
  typescript: true,
}, {
  rules: {
    'no-console': 'off',
    'style/semi': ['error', 'always'],
  },
  ignores: [
    'node_modules',
    'dist',
    'coverage',
    '**/*.d.ts',
  ],
});
