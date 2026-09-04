import { defineConfig } from 'astro/config';
import { siteUrl } from './site.config.mjs';

export default defineConfig({
  site: siteUrl,
  output: 'static',
});
