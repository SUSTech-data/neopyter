import antfu from '@antfu/eslint-config';

export default antfu({
  stylistic: {
    indent: 2,
    quotes: 'single',
  },
  toml: false,
  yaml: false,
  markdown: false,
  typescript: true,
  gitignore: true,
}, {
  rules: {
    'no-console': 'off',
    'style/semi': ['error', 'always'],
  },
});
