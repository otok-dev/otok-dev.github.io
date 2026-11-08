// Otok (c) Alexander A Pototskiy
// SPDX-License-Identifier: CC0-1.0
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://otok-dev.github.io',
  integrations: [
    starlight({
      title: 'Otok',
      description: 'Native libraries built from source into XCFrameworks for Xcode and SwiftPM — and for Android, Windows and Linux.',
      // English is the source; translations go into src/content/docs/<lang>/ under the same paths. A page not
      // translated yet is shown in English with a notice.
      defaultLocale: 'root',
      locales: {
        root: { label: 'English', lang: 'en' },
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/otok-dev/otok' },
        { icon: 'heart', label: 'Sponsor', href: 'https://github.com/sponsors/apotocki' },
      ],
      components: {
        Footer: './src/components/Footer.astro',
      },
      editLink: {
        baseUrl: 'https://github.com/otok-dev/otok-dev.github.io/edit/main/',
      },
      sidebar: [
        { label: 'Why otok', link: '/why/' },
        { label: 'Get started', items: [{ autogenerate: { directory: 'start' } }] },
        { label: 'Guides', items: [{ autogenerate: { directory: 'guides' } }] },
        { label: 'Recipes', items: [{ autogenerate: { directory: 'recipes' } }] },
        { label: 'Concepts', items: [{ autogenerate: { directory: 'concepts' } }] },
        { label: 'Reference', items: [{ autogenerate: { directory: 'reference' } }] },
        { label: 'Library catalog', link: 'https://otok-dev.github.io/index/', attrs: { target: '_self' } },
      ],
    }),
  ],
});
