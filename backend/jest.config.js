// Faz 7.2 — birim testleri (bkz. `src/**/*.spec.ts`). E2E testleri AYRI bir
// konfigürasyonla çalışır (`test/jest-e2e.json`, `npm run test:e2e`) çünkü
// gerçek bir Postgres/Redis bağlantısı gerektirirler; birim testleri
// (`npm test`) hiçbir dış servise ihtiyaç duymaz ve CI'da her zaman çalışır.
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: {
    '^.+\\.(t|j)s$': 'ts-jest',
  },
  collectCoverageFrom: ['**/*.(t|j)s', '!**/*.module.ts', '!**/*.dto.ts', '!main.ts'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
};
