// Pure parsing for X Bookmarks GraphQL payloads → clean bookmark records.
// Kept separate from the browser code so it can be unit-tested without a browser.
// Defensive on purpose: X changes this shape periodically, so every access is
// optional-chained and the raw payload is always saved by the scraper.

export function parseBookmarks(responses) {
  const byId = new Map();
  for (const data of responses) {
    const timeline =
      data?.data?.bookmark_timeline_v2?.timeline ??
      data?.data?.bookmark_timeline?.timeline;
    for (const inst of timeline?.instructions ?? []) {
      const entries = inst?.entries ?? (inst?.entry ? [inst.entry] : []);
      for (const entry of entries) {
        const bm = toBookmark(entry?.content?.itemContent?.tweet_results?.result);
        if (bm) byId.set(bm.id, bm);
      }
    }
  }
  return [...byId.values()];
}

function toBookmark(result) {
  if (!result) return null;
  const tweet = result.tweet ?? result; // unwrap TweetWithVisibilityResults
  const legacy = tweet?.legacy;
  const id = tweet?.rest_id ?? legacy?.id_str;
  if (!legacy || !id) return null;

  const ur = tweet?.core?.user_results?.result;
  const handle = ur?.legacy?.screen_name ?? ur?.core?.screen_name ?? null;
  const name = ur?.legacy?.name ?? ur?.core?.name ?? null;

  const mediaSrc = legacy?.extended_entities?.media ?? legacy?.entities?.media ?? [];
  const media = mediaSrc.map((m) => ({
    type: m.type,
    url: m.media_url_https ?? m.media_url ?? null,
    expanded: m.expanded_url ?? null,
  }));
  const urls = (legacy?.entities?.urls ?? []).map((u) => u.expanded_url).filter(Boolean);

  return {
    id: String(id),
    author_handle: handle ? `@${handle}` : null,
    author_name: name,
    text: legacy.full_text ?? legacy.text ?? '',
    url: handle ? `https://x.com/${handle}/status/${id}` : `https://x.com/i/web/status/${id}`,
    created_at: legacy.created_at ?? null,
    lang: legacy.lang ?? null,
    media,
    urls,
  };
}

export function toMarkdown(bookmarks) {
  const out = ['# X bookmarks', '', `Total: **${bookmarks.length}**`, ''];
  for (const b of bookmarks) {
    const who = [b.author_name, b.author_handle].filter(Boolean).join(' ') || b.id;
    out.push(`## ${who}${b.created_at ? ` · ${b.created_at}` : ''}`);
    out.push('');
    out.push((b.text || '').trim() || '_(no text)_');
    out.push('');
    if (b.urls.length) out.push(`Links: ${b.urls.join(' · ')}`);
    if (b.media.length) out.push(`Media: ${b.media.map((m) => m.url).filter(Boolean).join(' · ')}`);
    out.push(`🔗 ${b.url}`);
    out.push('', '---', '');
  }
  return out.join('\n');
}
