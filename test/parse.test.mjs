import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseBookmarks, toMarkdown } from '../src/parse.mjs';

// A representative slice of X's bookmark_timeline_v2 GraphQL response.
const sample = {
  data: { bookmark_timeline_v2: { timeline: { instructions: [
    { type: 'TimelineAddEntries', entries: [
      { entryId: 'tweet-123', content: { itemContent: { tweet_results: { result: {
        rest_id: '123',
        core: { user_results: { result: { legacy: { screen_name: 'jack', name: 'Jack' } } } },
        legacy: {
          full_text: 'hello world',
          created_at: 'Wed Jul 01 12:00:00 +0000 2026',
          lang: 'en',
          entities: { urls: [{ expanded_url: 'https://example.com' }] },
          extended_entities: { media: [{ type: 'photo', media_url_https: 'https://pbs.twimg.com/x.jpg' }] },
        },
      } } } } },
      // A cursor entry (no itemContent) must be ignored.
      { entryId: 'cursor-bottom', content: { entryType: 'TimelineTimelineCursor', value: 'CURSOR' } },
    ] },
  ] } } },
};

test('parses a bookmark and skips cursor entries', () => {
  const bms = parseBookmarks([sample]);
  assert.equal(bms.length, 1);
  const b = bms[0];
  assert.equal(b.id, '123');
  assert.equal(b.author_handle, '@jack');
  assert.equal(b.author_name, 'Jack');
  assert.equal(b.text, 'hello world');
  assert.equal(b.url, 'https://x.com/jack/status/123');
  assert.equal(b.created_at, 'Wed Jul 01 12:00:00 +0000 2026');
  assert.equal(b.media.length, 1);
  assert.equal(b.media[0].url, 'https://pbs.twimg.com/x.jpg');
  assert.deepEqual(b.urls, ['https://example.com']);
});

test('dedupes by tweet id across paginated responses', () => {
  assert.equal(parseBookmarks([sample, sample]).length, 1);
});

test('handles newer user schema (core.*) and TweetWithVisibilityResults wrapping', () => {
  const wrapped = { data: { bookmark_timeline_v2: { timeline: { instructions: [
    { entries: [{ content: { itemContent: { tweet_results: { result: {
      __typename: 'TweetWithVisibilityResults',
      tweet: {
        rest_id: '456',
        core: { user_results: { result: { core: { screen_name: 'alice', name: 'Alice' } } } },
        legacy: { full_text: 'hi' },
      },
    } } } } }] },
  ] } } } };
  const bms = parseBookmarks([wrapped]);
  assert.equal(bms.length, 1);
  assert.equal(bms[0].id, '456');
  assert.equal(bms[0].author_handle, '@alice');
});

test('returns nothing for empty / malformed payloads (no throw)', () => {
  assert.deepEqual(parseBookmarks([]), []);
  assert.deepEqual(parseBookmarks([{}, { data: {} }, null]), []);
});

test('toMarkdown renders the count and the entries', () => {
  const md = toMarkdown(parseBookmarks([sample]));
  assert.match(md, /Total: \*\*1\*\*/);
  assert.match(md, /@jack/);
  assert.match(md, /hello world/);
  assert.match(md, /x\.com\/jack\/status\/123/);
});
