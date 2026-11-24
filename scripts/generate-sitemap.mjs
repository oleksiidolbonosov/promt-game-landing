import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const siteOrigin = "https://promptlyss.com";
const sitemapPath = join(root, "sitemap.xml");
const excludedSegments = new Set([
  "api",
  "admin",
  "challenge",
  "challenges",
  "private",
  "preview",
  "test",
  "tests",
]);
const ignoredDirectories = new Set([
  ".git",
  ".wrangler",
  "node_modules",
  "build",
  "dist",
  "out",
]);

function listHtmlFiles(directory) {
  const files = [];

  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name) && !entry.name.startsWith(".")) {
        files.push(...listHtmlFiles(join(directory, entry.name)));
      }
      continue;
    }

    if (entry.isFile() && entry.name.toLowerCase().endsWith(".html")) {
      files.push(join(directory, entry.name));
    }
  }

  return files;
}

function attributes(tag) {
  return Object.fromEntries(
    [...tag.matchAll(/([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g)].map(
      (match) => [match[1].toLowerCase(), match[2] ?? match[3] ?? match[4] ?? ""],
    ),
  );
}

function routeForFile(file) {
  const page = relative(root, file).split(sep).join("/");
  if (page === "index.html") return "/";
  if (page.endsWith("/index.html")) return `/${page.slice(0, -"index.html".length)}`;
  return `/${page}`;
}

function isExplicitlyNoIndex(html) {
  return [...html.matchAll(/<meta\b[^>]*>/gi)].some((match) => {
    const attrs = attributes(match[0]);
    return attrs.name?.toLowerCase() === "robots" && /\bnoindex\b/i.test(attrs.content ?? "");
  });
}

const urls = [];
const errors = [];

for (const file of listHtmlFiles(root)) {
  const route = routeForFile(file);
  const segments = route.toLowerCase().split("/").filter(Boolean);
  const basename = route.split("/").filter(Boolean).at(-1) ?? "index";

  if (
    segments.some(
      (segment) =>
        excludedSegments.has(segment) ||
        /^(?:api|challenge|private|preview|test)(?:[-_.]|$)/.test(segment),
    ) ||
    /^404(?:\.|$)/i.test(basename)
  ) {
    continue;
  }

  const html = readFileSync(file, "utf8");
  if (isExplicitlyNoIndex(html)) continue;

  const canonicalTag = [...html.matchAll(/<link\b[^>]*>/gi)]
    .map((match) => ({ tag: match[0], attrs: attributes(match[0]) }))
    .find(({ attrs }) => attrs.rel?.toLowerCase().split(/\s+/).includes("canonical"));

  if (!canonicalTag) {
    errors.push(`${relative(root, file)}: indexable HTML page is missing a canonical URL`);
    continue;
  }

  let canonical;
  try {
    canonical = new URL(canonicalTag.attrs.href);
  } catch {
    errors.push(`${relative(root, file)}: canonical URL is invalid`);
    continue;
  }

  if (
    canonical.origin !== siteOrigin ||
    canonical.pathname !== route ||
    canonical.search ||
    canonical.hash
  ) {
    // Excludes aliases and duplicate pages whose canonical points elsewhere.
    continue;
  }

  urls.push(canonical.href);
}

if (errors.length) {
  throw new Error(`Sitemap generation failed:\n${errors.join("\n")}`);
}

const uniqueUrls = [...new Set(urls)].sort((a, b) => a.localeCompare(b));
if (!uniqueUrls.length) throw new Error("Sitemap generation found no canonical indexable pages.");

const xmlEscape = (value) =>
  value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const xml = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  ...uniqueUrls.flatMap((url) => ["  <url>", `    <loc>${xmlEscape(url)}</loc>`, "  </url>"]),
  "</urlset>",
  "",
].join("\n");

writeFileSync(sitemapPath, xml, "utf8");
console.log(`Generated sitemap.xml with ${uniqueUrls.length} canonical page(s):`);
for (const url of uniqueUrls) console.log(`- ${url}`);
