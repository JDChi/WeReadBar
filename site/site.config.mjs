const defaultSiteUrl = 'https://wereadbar.jdchi.tech';
const configuredSiteUrl = process.env.SITE_URL ?? defaultSiteUrl;

export const siteUrl = configuredSiteUrl.replace(/\/+$/, '');
