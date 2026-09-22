import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import {
  category,
  cleanVietnameseName,
  curate,
  identityKeys,
  parsePlaylist,
  rankSources,
} from "./playlist.ts";

/** The iptv-org playlist for Vietnam, in the shape it is published in. */
const PRIMARY = `#EXTM3U
#EXTINF:-1 tvg-id="THVL1.vn@HD" tvg-logo="https://example.com/thvl1.png" group-title="General;News",THVL1 (1080p)
https://example.com/thvl1/index.m3u8
#EXTINF:-1 tvg-id="HTV7.vn@SD" tvg-logo="" group-title="Entertainment",HTV7 (720p)
https://example.com/htv7/index.m3u8
#EXTINF:-1 tvg-id="VinhLongTV4.vn@SD" tvg-logo="" group-title="Culture",Vinh Long TV 4 (720p)
https://example.com/vinhlong4/index.m3u8
#EXTINF:-1 tvg-id="DaNangTV1.vn@SD" tvg-logo="" group-title="General",Da Nang TV 1 (1080p)
https://example.com/danang1/index.m3u8
#EXTINF:-1 tvg-id="HmongTVNetwork.us@SD" tvg-logo="" group-title="Culture",Hmong TV Network (720p)
https://example.com/hmong/index.m3u8
#EXTINF:-1 tvg-id="UniquelyThai.vn@SD" tvg-logo="" group-title="Shop",Uniquely Thai (720p)
https://example.com/uniquelythai/index.m3u8
#EXTINF:-1 tvg-id="AnNinhTV.vn@HD" tvg-logo="" group-title="Undefined",An Ninh TV HD (1080p)
https://example.com/anninhtv/index.m3u8
#EXTINF:-1 tvg-id="VTV10.vn@HD" tvg-logo="" group-title="Education",VTV10 (1080p)
https://example.com/vtv10/index.m3u8
#EXTINF:-1 tvg-id="VTV10.vn@SD" tvg-logo="" group-title="Education",VTV10 SD (576p)
https://example.com/vtv10-sd/index.m3u8
#EXTINF:-1 tvg-id="VTV5TayNguyen.vn@HD" tvg-logo="" group-title="General",VTV5 Tay Nguyen HD (1080p)
https://example.com/vtv5-taynguyen/index.m3u8
#EXTINF:-1 tvg-id="HTVSports.vn@SD" tvg-logo="" group-title="Sports",HTV Sports (720p)
https://example.com/htvsports/index.m3u8
#EXTINF:-1 tvg-id="CanThoTV.vn@SD" tvg-logo="" group-title="General",Can Tho TV (720p)
https://example.com/cantho/index.m3u8
`;

/**
 * The collection, with the mess an automated scrape comes with: the same
 * stations under other names, channels the catalogue misses, and entries
 * that are not channels at all.
 */
const EXTRA = `#EXTM3U
#EXTINF:-1 group-title="THVL",THVL1 HD | Vĩnh Long
https://example.com/other/thvl1.m3u8
#EXTINF:-1 group-title="HTV",HTV7 HD
https://example.com/other/htv7.m3u8
#EXTINF:-1 tvg-logo="https://example.com/ltv1.png" group-title="Địa phương",LTV1 | Báo và Phát thanh – Truyền hình Lâm Đồng
https://example.com/lamdong1/chunklist.m3u8
#EXTINF:-1 group-title="Địa phương",Cần Thơ 1 HD - Báo và PTTH Thành Phố Cần Thơ
https://example.com/cantho1/chunklist.m3u8
#EXTINF:-1 group-title="VTVcab",ON Sports HD
https://example.com/onsports/index.m3u8
#EXTINF:-1 group-title="VIETNAM TV24",ช่อง WION
https://example.com/wion/index.m3u8
#EXTINF:-1 group-title="Undefined",Pudahuel TV (720p)
https://example.com/pudahuel/index.m3u8
#EXTINF:-1 group-title="VTV",VTC1 HD_kkk.m3u?dl=0.ref-250415-039.done
https://example.com/vtc1/index.m3u8
#EXTINF:-1 group-title="Địa phương",Hà Nam TV
https://example.com/hanam/next.php?id=hanam
#EXTINF:-1 group-title="Địa phương",Bắc Giang TV
https://dl.dropboxusercontent.com/s/xyz/bacgiang.m3u8
#EXTINF:-1 group-title="Địa phương",DRT HD | TH Đắk Lắk
https://example.com/drt/index.m3u8
#EXTINF:-1 group-title="Địa phương",Đắk Lắk
https://example.com/daklak/chunklist.m3u8
#EXTINF:-1 group-title="INDONESIA",VTV HD
https://example.com/vtv-id/index.m3u8
#EXTINF:-1 ,[智利]VTV Aconcaga
https://example.com/aconcaga/playlist.m3u8
#EXTINF:-1 group-title="Địa phương",Vĩnh Long 5
https://example.com/vinhlong5/index.m3u8
#EXTINF:-1 group-title="Địa phương",Đà Nẵng
https://example.com/danang/index.m3u8
#EXTINF:-1 group-title="TV Nasional",SCTV
https://example.com/sctv-id/index.m3u8
#EXTINF:-1 group-title="ANQP",ANTV
https://example.com/antv/index.m3u8
#EXTINF:-1 ,Vietnam ANTV
https://example.com/vietnam-antv/index.m3u8
#EXTINF:-1 group-title="INDONESIA SD",ANTV
https://example.com/antv-id/index.m3u8
#EXTINF:-1 tvg-id="KhmerTV.vn" tvg-country="VN" group-title="Vietnam越南",KhmerTV
https://example.com/khmertv/index.m3u8
#EXTINF:-1 group-title="ANQP",QPVN Quốc Phòng
https://example.com/qpvn-1/index.m3u8
#EXTINF:-1 group-title="ANQP",QPVN QUỐC PHÒNG VIỆT NAM
https://example.com/qpvn-2/index.m3u8
#EXTINF:-1 group-title="ANQP",Quốc Phòng VN
https://example.com/qpvn-3/index.m3u8
#EXTINF:-1 group-title="THVL",THVL5
https://example.com/thvl5/index.m3u8
#EXTINF:-1 group-title="Địa phương",Vĩnh Long 5
https://example.com/vinhlong5-2/index.m3u8
#EXTINF:-1 group-title="Thể thao",VTV5 TN
https://example.com/vtv5-tn/index.m3u8
#EXTINF:-1 group-title="Thể thao",HTVC Thể Thao
https://example.com/htvc-thethao/index.m3u8
#EXTINF:-1 group-title="Địa phương",Cần Thơ THTPCT
https://example.com/cantho-thtpct/index.m3u8
#EXTINF:-1 group-title="Địa phương",THTPCT1 Cần Thơ 1
https://example.com/cantho-thtpct1/index.m3u8
`;

const build = () => curate(parsePlaylist(PRIMARY), parsePlaylist(EXTRA));
const names = () => build().map((channel) => channel.name);

Deno.test("parses the fields a channel row needs", () => {
  const [thvl1] = parsePlaylist(PRIMARY);

  // The name loses the quality badge, which becomes a field of its own.
  assertEquals(thvl1.name, "THVL1");
  assertEquals(thvl1.quality, "1080p");
  assertEquals(thvl1.groups, ["General", "News"]);
  assertEquals(thvl1.logo, "https://example.com/thvl1.png");
});

Deno.test("reads the headers a CDN wants before it hands the stream over", () => {
  const entries = parsePlaylist(`#EXTM3U
#EXTINF:-1 group-title="General",Some Channel
#EXTVLCOPT:http-referrer=https://example.com/
#EXTVLCOPT:http-user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64), Chrome
https://example.com/some/playlist.m3u8
`);

  assertEquals(entries[0].headers, {
    "Referer": "https://example.com/",
    // The user agent has a comma in it, so the name is what follows the
    // last one, not the first.
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64), Chrome",
  });
  assertEquals(entries[0].name, "Some Channel");
});

Deno.test("keeps the catalogue whole and fills the gaps around it", () => {
  const found = names();

  assert(found.includes("THVL1"));
  assert(found.includes("HTV7"));
  assert(found.includes("LTV1 Lâm Đồng"));
  // The collection's `Cần Thơ 1 HD - Báo và PTTH Thành Phố Cần Thơ` is the
  // catalogue's `Can Tho TV`, so it joins that row rather than making one.
  assert(found.includes("Can Tho TV"));
  assert(found.includes("ON Sports"));
});

Deno.test("a channel both lists carry is one row, the catalogue's", () => {
  const thvl1 = build().filter((c) => c.name.startsWith("THVL1"));

  assertEquals(thvl1.length, 1);
  // The kept entry is the catalogue's: it is the one with the logo and a
  // category the app's chips can translate.
  assertEquals(thvl1[0].logo, "https://example.com/thvl1.png");
  assertEquals(thvl1[0].categories, ["General", "News"]);
  // The other list's link stays, as something for the checker to fall back
  // on — one of these is usually the dead one.
  assertEquals(thvl1[0].sources, [
    "https://example.com/thvl1/index.m3u8",
    "https://example.com/other/thvl1.m3u8",
  ]);
});

Deno.test("a station listed by call sign and by province is one row", () => {
  const daklak = build().filter((c) => c.name.includes("Đắk Lắk"));

  assertEquals(daklak.length, 1);
  assertEquals(daklak[0].sources.length, 2);
});

Deno.test("drops what is not a Vietnamese channel on a playable stream", () => {
  const found = names();

  // Another country's channel, whatever shelf the collection put it on.
  assertFalse(found.includes("ช่อง WION"));
  assertFalse(found.some((n) => n.includes("Pudahuel")));
  // Bookkeeping the scraper left in the name.
  assertFalse(found.some((n) => n.includes(".done")));
  // A redirector and a file-sharing link are not streams.
  assertFalse(found.some((n) => n.includes("Hà Nam")));
  assertFalse(found.some((n) => n.includes("Bắc Giang")));
});

Deno.test("another country's channel by the same name is not ours", () => {
  // Both of these reached the page. `VTV` is Vietnam's national broadcaster
  // and also Indonesia's channel, the Maldives', Uruguay's and Chile's — and
  // every one of those is called just that, where a Vietnamese VTV channel
  // always carries a number or a province after it.
  assertFalse(names().includes("VTV"));
  assertFalse(names().includes("VTV HD"));
});

Deno.test("the catalogue's own foreign channels are left out too", () => {
  const found = names();

  // The catalogue's Vietnamese file also carries what Vietnamese-speaking
  // communities abroad watch, and their neighbours' channels with it. The
  // `tvg-id` says so outright.
  assertFalse(found.includes("Hmong TV Network"));
  // And some of them it labels `.vn` regardless, so the name has to say it.
  assertFalse(found.includes("Uniquely Thai"));
  // Even written with nothing between the word and the `TV`.
  assertFalse(found.includes("KhmerTV"));
  // `SCTV` is Vietnam's cable network, numbered, and also Indonesia's
  // biggest station, bare.
  assertFalse(found.includes("SCTV"));
});

Deno.test("one province's channels stand together, however they are spelled", () => {
  const found = names();
  const at = (name: string) => found.indexOf(name);

  // Accents sort after `z`, and a name with `TV` in it sorts after every
  // number — so spelled as the two playlists spell them, these ended up at
  // the far end of the list instead of beside each other.
  assertEquals(at("Vĩnh Long 5"), at("Vinh Long TV 4") + 1);
  assertEquals(at("Da Nang TV 1"), at("Đà Nẵng") + 1);
});

Deno.test("a call sign and the name it stands for are one channel", () => {
  const antv = build().filter((c) => /An Ninh|ANTV/.test(c.name));

  // `ANTV` is `An Ninh TV`, the police channel, and the sources write it
  // both ways — and once more as `Vietnam ANTV`.
  assertEquals(antv.length, 1);
  assertEquals(antv[0].name, "An Ninh TV HD");
  assertEquals(antv[0].sources, [
    "https://example.com/anninhtv/index.m3u8",
    "https://example.com/antv/index.m3u8",
    "https://example.com/vietnam-antv/index.m3u8",
  ]);
});

Deno.test("a name that spells its own call sign out is not two channels", () => {
  const qpvn = build().filter((c) => /QPVN|Quốc Phòng/i.test(c.name));

  // `QPVN` is `Quốc Phòng Việt Nam`, and the sources write it every way
  // there is — twice over in the same name, in two of them.
  assertEquals(qpvn.length, 1);
  assertEquals(qpvn[0].sources.length, 3);
});

Deno.test("the many ways one station is written come to one row", () => {
  const found = names();
  const once = (pattern: RegExp) =>
    found.filter((name) => pattern.test(name)).length;

  // `THVL5` is `Vĩnh Long 5`, `VTV5 TN` is `VTV5 Tây Nguyên`, `HTVC Thể
  // Thao` is `HTV Sports`, and `Cần Thơ`'s own station spells its call sign
  // out as the city it is named after.
  assertEquals(once(/Vĩnh Long 5|THVL5/), 1);
  assertEquals(once(/VTV5 T/i), 1);
  assertEquals(once(/HTVC? (Sports|Thể ?thao)/i), 1);
  assertEquals(once(/Cần Thơ|Can Tho/i), 1);
  // The catalogue's spelling is the one that stays, and everything the
  // others found stays with it as a spare link.
  const cantho = build().find((c) => c.name === "Can Tho TV")!;
  assertEquals(cantho.sources.length, 4);
});

Deno.test("two feeds of one station in the catalogue are one row", () => {
  const vtv10 = build().filter((c) => c.name.startsWith("VTV10"));

  // `VTV10` and `VTV10 SD` are the same channel at two resolutions, and the
  // second is a spare link rather than a row of its own.
  assertEquals(vtv10.length, 1);
  assertEquals(vtv10[0].sources, [
    "https://example.com/vtv10/index.m3u8",
    "https://example.com/vtv10-sd/index.m3u8",
  ]);
});

Deno.test("a channel shelved under another country is theirs", () => {
  // `ANTV` is also one of Indonesia's biggest stations, and the only thing
  // telling that entry from ours is the shelf it sits on. Left in, its
  // stream became one of the spares the app falls back on for the police
  // channel.
  const antv = build().find((c) => c.name === "An Ninh TV HD")!;

  assertFalse(antv.sources.includes("https://example.com/antv-id/index.m3u8"));
});

Deno.test("the country in the brackets is read before they are stripped", () => {
  // `[智利]` is Chile. The brackets go, because the ones the app cares about
  // are `[Geo-blocked]` and `[Not 24/7]` — but what goes with them is the
  // clearest statement in the entry of where the channel is from, so it is
  // read first.
  assertFalse(names().some((name) => name.includes("Aconcaga")));
});

Deno.test("the mirror that names the best picture leads", () => {
  // A CDN often publishes one link per rendition beside the adaptive
  // master. They all play, so nothing further down tells them apart, and the
  // channel opened on whichever the playlist wrote first — TVB Vietnam
  // opened on 480p.
  assertEquals(
    rankSources([
      "https://cdn.example.com/playlist480p.m3u8",
      "https://cdn.example.com/playlist.m3u8",
      "https://cdn.example.com/playlist1080p.m3u8",
    ]),
    [
      "https://cdn.example.com/playlist1080p.m3u8",
      // The master in the middle: the player can climb and fall with the
      // line, but it starts on the smallest rendition, which is the first
      // one a master lists.
      "https://cdn.example.com/playlist.m3u8",
      "https://cdn.example.com/playlist480p.m3u8",
    ],
  );
});

Deno.test("a number in the host is not a rendition", () => {
  // `…-us-4491.playouts…` is a hostname, not a 4491p picture.
  assertEquals(
    rankSources([
      "https://amg-us-4491.playouts.example.com/playlist.m3u8",
      "https://cdn.example.com/playlist720p.m3u8",
    ])[0],
    "https://cdn.example.com/playlist720p.m3u8",
  );
});

Deno.test("every channel has a slug of its own", () => {
  const channels = build();
  const slugs = new Set(channels.map((c) => c.slug));

  assertEquals(slugs.size, channels.length);
  assertFalse(slugs.has(""));
});

Deno.test("the stream most likely to play is the one the app opens", () => {
  const [daklak] = curate(
    [],
    parsePlaylist(`#EXTM3U
#EXTINF:-1 group-title="Địa phương",DRT | TH Đắk Lắk
https://bugsfreeweb.github.io/mirror/drt.m3u8
#EXTINF:-1 group-title="Địa phương",Đắk Lắk TV
https://freem3u.xyz/api/live/play.m3u8?vid=51
#EXTINF:-1 group-title="Địa phương",Đắk Lắk
https://cdn.drt.vn/live/daklak/chunklist.m3u8
`),
  );

  // The station's own CDN first, then the proxy that looks it up, and last
  // the copy someone committed to a repository.
  assertEquals(daklak.sources, [
    "https://cdn.drt.vn/live/daklak/chunklist.m3u8",
    "https://freem3u.xyz/api/live/play.m3u8?vid=51",
    "https://bugsfreeweb.github.io/mirror/drt.m3u8",
  ]);
});

Deno.test("the merge does not depend on the order the entries arrive in", () => {
  const forward = parsePlaylist(EXTRA);
  const backward = [...forward].reverse();

  const one = curate(parsePlaylist(PRIMARY), forward).map((c) => c.slug);
  const other = curate(parsePlaylist(PRIMARY), backward).map((c) => c.slug);

  assertEquals(one.sort(), other.sort());
});

Deno.test("drops the broadcaster boilerplate around the channel", () => {
  assertEquals(
    cleanVietnameseName("LTV1 | Báo và Phát thanh – Truyền hình Lâm Đồng"),
    "LTV1 Lâm Đồng",
  );
  assertEquals(
    cleanVietnameseName("QTV1 HD | TH Quảng Ninh"),
    "QTV1 Quảng Ninh",
  );
  assertEquals(
    cleanVietnameseName("Cần Thơ 1 HD - Báo và PTTH Thành Phố Cần Thơ"),
    "Cần Thơ 1",
  );
});

Deno.test("leaves a Vietnamese word that merely starts with a stripped one", () => {
  // `TH` is how the sources write "truyền hình", but `Thơ`, `Thể` and `Thọ`
  // are words in their own right.
  assertEquals(cleanVietnameseName("Cần Thơ 2"), "Cần Thơ 2");
  assertEquals(cleanVietnameseName("HTV Thể Thao HD"), "HTV Thể Thao");
  assertEquals(cleanVietnameseName("PTV Phú Thọ"), "PTV Phú Thọ");
  assertEquals(cleanVietnameseName("THVL4 HD"), "THVL4");
});

Deno.test("a name that is nothing but boilerplate is left as it was", () => {
  assertEquals(cleanVietnameseName("Truyền hình"), "Truyền hình");
});

/** Two names are one channel when any of the keys they go by meet. */
const sameChannel = (first: string, second: string) =>
  [...identityKeys(first)].some((key) => identityKeys(second).has(key));

Deno.test("two spellings of one station are one channel", () => {
  assert(sameChannel("THVL1 HD", "Kênh THVL1"));
  assert(sameChannel("Cần Thơ TV1 (1080p)", "Can Tho 1"));
  assert(sameChannel("HanoiTV1 Hà Nội", "Hà Nội 1"));
  // The station number written out twice — once in the call sign, once
  // after the province.
  assert(sameChannel("LTV1 Lâm Đồng 1", "LTV1 Lâm Đồng"));
  // `DRT` is Đắk Lắk's station, so a list carrying both is carrying one
  // channel twice.
  assert(sameChannel("DRT Đắk Lắk", "Đắk Lắk"));
  assert(sameChannel("THP3 Hải Phòng", "Hải Phòng 3"));
});

Deno.test("two stations are not", () => {
  assertFalse(sameChannel("HTV1", "H1"));
  assertFalse(sameChannel("VTV1", "VTV10"));
  assertFalse(sameChannel("Cần Thơ 1", "Cần Thơ 2"));
  assertFalse(sameChannel("LTV1 Lâm Đồng 2", "LTV1 Lâm Đồng"));
  // A national network in front of a province is that network's own station
  // there, not the province's channel.
  assertFalse(sameChannel("VTV Cần Thơ", "Cần Thơ 1"));
  assertFalse(sameChannel("VTV Cần Thơ", "VTV"));
});

Deno.test("reads a category off the name, since the source files by network", () => {
  assertEquals(category("ON Sports HD"), "Sports");
  assertEquals(category("HTVC Phim"), "Movies");
  assertEquals(category("ON BiBi"), "Kids");
  // A local station says nothing about itself beyond being a channel.
  assertEquals(category("Cần Thơ 1"), "General");
});
