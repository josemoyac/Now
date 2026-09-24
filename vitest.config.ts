import { defineConfig } from 'vitest/config';
export default defineConfig({test:{include:['packages/**/*.test.ts','apps/api/test/**/*.test.ts','apps/mobile/**/*.test.ts'],testTimeout:30000,hookTimeout:60000,fileParallelism:false}});
