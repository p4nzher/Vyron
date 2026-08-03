// Faz 7.2 — `npm run lint` (package.json) bu dosyaya ihtiyaç duyuyordu ama
// depoda mevcut değildi; CI'da (bkz. `.github/workflows/backend-ci.yml`) lint
// adımının anlamlı bir şekilde çalışabilmesi için eklendi. Standart NestJS
// başlangıç şablonuyla uyumlu, zaten kurulu olan `@typescript-eslint/*`
// paketlerini (bkz. `package.json` devDependencies) kullanır.
module.exports = {
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: 'tsconfig.json',
    tsconfigRootDir: __dirname,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
  root: true,
  env: {
    node: true,
    jest: true,
  },
  ignorePatterns: ['.eslintrc.js', 'dist', 'node_modules'],
  rules: {
    '@typescript-eslint/interface-name-prefix': 'off',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
    '@typescript-eslint/no-explicit-any': 'warn',
    '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    'no-console': ['warn', { allow: ['warn', 'error'] }],
  },
};
