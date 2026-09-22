/**
 * Turning two IPTV playlists into the Vietnamese channel list the app shows.
 *
 * `iptv-org` publishes a curated file per country, but its Vietnamese one is
 * thin: around eighty channels, which leaves most of the provincial stations
 * and whole cable bouquets out. A second, community-collected playlist has
 * them, and almost nothing else it holds is usable — it is gathered by a
 * scraper, so it is full of web pages, redirectors, file-sharing links, other
 * countries' channels and the same station listed a dozen ways.
 *
 * Everything here is about getting from those two files to one list: parse,
 * throw out what is not a channel, work out when two names are one station,
 * and keep the spare links so the checker has something to fall back on.
 */

export interface Channel {
  /** Identity of the station, stable across runs. */
  slug: string;
  name: string;
  /** Every stream found for this station, most likely to play first. */
  sources: string[];
  logo: string | null;
  /** The iptv-org category vocabulary; a channel is often filed under several. */
  categories: string[];
  quality: string | null;
  isGeoBlocked: boolean;
  isIntermittent: boolean;
  headers: Record<string, string>;
}

/** One `#EXTINF` entry, before anything has been decided about it. */
interface Entry {
  id: string;
  name: string;
  /**
   * The name as the playlist wrote it, brackets and all.
   *
   * The collection marks a channel's country in them — `[智利]VTV Aconcaga`
   * is Chile's — and [cleanName] strips brackets, because the ones that
   * matter to the app are `[Geo-blocked]` and `[Not 24/7]`. What is thrown
   * out with them is the clearest statement in the entry of where the
   * channel is from, so it is kept here for [isVietnamese] to read.
   */
  rawName: string;
  url: string;
  logo: string | null;
  groups: string[];
  quality: string | null;
  isGeoBlocked: boolean;
  isIntermittent: boolean;
  headers: Record<string, string>;
}

const ATTRIBUTE = /([\w-]+)="([^"]*)"/g;
const QUALITY = /\((\d{3,4}p)\)/;
const FLAG = /\[[^\]]*\]/g;

/**
 * Reads an M3U playlist.
 *
 * Nothing is judged here — that is [curate]'s job — beyond dropping entries
 * with no URL and repeats of a URL already seen.
 */
export function parsePlaylist(content: string): Entry[] {
  const entries: Entry[] = [];
  const seen = new Set<string>();

  let attributes: Record<string, string> = {};
  let name = "";
  let headers: Record<string, string> = {};
  let inEntry = false;

  for (const rawLine of content.split("\n")) {
    const line = rawLine.trim();
    if (line === "") continue;

    if (line.startsWith("#EXTINF:")) {
      attributes = {};
      for (const match of line.matchAll(ATTRIBUTE)) {
        attributes[match[1]] = match[2];
      }
      // The display name is whatever follows the last comma, after the
      // attributes — which may themselves contain commas (a user agent does).
      const comma = line.lastIndexOf(",");
      name = comma === -1 ? "" : line.slice(comma + 1).trim();
      headers = headersFrom(attributes);
      inEntry = true;
      continue;
    }

    // Playback options VLC writes on their own line; the same two headers
    // some entries carry as attributes instead.
    if (line.startsWith("#EXTVLCOPT:")) {
      const option = line.slice("#EXTVLCOPT:".length);
      const separator = option.indexOf("=");
      if (separator > 0 && inEntry) {
        const header = headerName(option.slice(0, separator).trim());
        const value = option.slice(separator + 1).trim();
        if (header && value !== "") headers[header] = value;
      }
      continue;
    }

    if (line.startsWith("#")) continue;
    if (!inEntry) continue;

    inEntry = false;
    if (!line.startsWith("http")) continue;
    if (seen.has(line)) continue;
    seen.add(line);

    const logo = attributes["tvg-logo"] ?? "";
    const group = attributes["group-title"] ?? "";
    const cleaned = cleanName(name);
    entries.push({
      id: attributes["tvg-id"] || line,
      name: cleaned === "" ? line : cleaned,
      rawName: name,
      url: line,
      logo: logo === "" ? null : logo,
      groups: group.split(";").map((g) => g.trim()).filter((g) => g !== ""),
      quality: QUALITY.exec(name)?.[1] ?? null,
      isGeoBlocked: name.includes("[Geo-blocked]"),
      isIntermittent: name.includes("[Not 24/7]"),
      headers,
    });
  }

  return entries;
}

function headersFrom(attributes: Record<string, string>) {
  const headers: Record<string, string> = {};
  for (const [key, value] of Object.entries(attributes)) {
    const header = headerName(key);
    if (header && value !== "") headers[header] = value;
  }
  return headers;
}

/**
 * The HTTP header an M3U option name stands for, or null when it is one of
 * the many options that says nothing about the request.
 */
function headerName(key: string): string | null {
  switch (key.toLowerCase()) {
    case "http-referrer":
    case "http-referer":
      return "Referer";
    case "http-user-agent":
      return "User-Agent";
    case "http-origin":
      return "Origin";
    default:
      return null;
  }
}

function cleanName(raw: string): string {
  return raw
    .replace(FLAG, "")
    .replace(QUALITY, "")
    .replace(/\s+/g, " ")
    .trim();
}

// ---------------------------------------------------------------------------
// Curation
// ---------------------------------------------------------------------------

/**
 * The channel list, from the catalogue's entries and the collection's.
 *
 * Everything the catalogue lists as Vietnamese is kept — it is curated by
 * hand and its entries are the ones with a logo and a real category. The
 * collection only
 * ever adds: a station it spells differently joins the row that is already
 * there, and its link becomes a spare for the checker to try.
 */
export function curate(primary: Entry[], extra: Entry[]): Channel[] {
  const rows: Row[] = [];
  /** Which row each key a station goes by currently belongs to. */
  const owner = new Map<string, number>();
  const urls = new Set<string>();

  const claim = (keys: Iterable<string>, index: number) => {
    for (const key of keys) {
      owner.set(key, index);
      rows[index].keys.add(key);
    }
  };

  const add = (entry: Entry, name: string, categories: string[]) => {
    rows.push({
      entry,
      name,
      categories,
      sources: [entry.url],
      keys: new Set(),
      absorbed: false,
    });
    claim(identityKeys(name), rows.length - 1);
  };

  // The catalogue is trusted for everything but the country: its Vietnamese
  // file also carries the channels Vietnamese-speaking communities abroad
  // watch, and a few of their neighbours' — `Hmong TV Network` and
  // `Lao-Thai TV` are both filed here under an American `tvg-id`.
  for (const entry of primary) {
    if (urls.has(entry.url)) continue;
    if (!isVietnamese(entry)) continue;
    urls.add(entry.url);

    // The catalogue lists one station twice when it has two feeds of it —
    // `VTV10` beside `VTV10 SD`. The second is a spare link for the first,
    // not a row of its own.
    const keys = identityKeys(entry.name);
    const owned = [...keys]
      .map((key) => owner.get(key))
      .find((index) => index !== undefined);
    if (owned !== undefined) {
      rows[owned].sources.push(entry.url);
      claim(keys, owned);
      continue;
    }

    add(entry, entry.name, entry.groups);
  }

  // The names that carry both a call sign and a province go first. They are
  // what ties `THVL1` to `Vĩnh Long 1`, and until one of them has been read
  // those two look like different stations — so reading them last would
  // leave the list holding both, decided by nothing but playlist order.
  const usable = extra.filter((entry) =>
    isUsable(entry) && !urls.has(entry.url)
  );
  const named = usable.map((entry) => {
    const name = cleanVietnameseName(entry.name);
    return { entry, name, keys: identityKeys(name) };
  });
  named.sort((a, b) => b.keys.size - a.keys.size);

  for (const { entry, name, keys } of named) {
    if (urls.has(entry.url)) continue;
    if ([...keys].some((key) => key === "")) continue;
    urls.add(entry.url);

    const matches = [...new Set([...keys].map((key) => owner.get(key)))]
      .filter((index): index is number => index !== undefined)
      .sort((a, b) => a - b);

    if (matches.length === 0) {
      add(entry, name, [category(name)]);
      continue;
    }

    // One name can turn out to join two rows that were never known to be the
    // same station. The earlier row keeps the channel — it is the one the
    // catalogue gave us — and the rest hand over their streams and their
    // names to it.
    const [survivor, ...absorbed] = matches;
    for (const index of absorbed) {
      rows[survivor].sources.push(...rows[index].sources);
      claim(rows[index].keys, survivor);
      rows[index].absorbed = true;
      rows[index].sources = [];
    }
    claim(keys, survivor);
    rows[survivor].sources.push(entry.url);
  }

  return rows
    .filter((row) => !row.absorbed)
    .map((row) => ({
      slug: "",
      name: row.name,
      sources: rankSources(row.sources),
      logo: row.entry.logo,
      categories: row.categories,
      quality: row.entry.quality,
      isGeoBlocked: row.entry.isGeoBlocked,
      isIntermittent: row.entry.isIntermittent,
      headers: row.entry.headers,
    }))
    .sort((a, b) => compareChannelNames(a.name, b.name))
    .map(withSlug(new Set<string>()));
}

/** One channel while it is still being put together. */
interface Row {
  entry: Entry;
  name: string;
  categories: string[];
  sources: string[];
  keys: Set<string>;
  absorbed: boolean;
}

/**
 * Gives each channel its slug, which is a row's primary key — so two
 * channels the merge could not tell apart still have to end up with
 * different ones.
 */
function withSlug(taken: Set<string>) {
  return (channel: Channel): Channel => {
    const base = dedupeKey(channel.name) ||
      foldAccents(channel.name).replace(/[^a-z0-9]/g, "") || "channel";
    let slug = base;
    for (let n = 2; taken.has(slug); n++) slug = `${base}-${n}`;
    taken.add(slug);
    return { ...channel, slug };
  };
}

/** Whether an entry of the collection has any business on the page. */
export function isUsable(entry: Entry): boolean {
  return isPlayableStream(entry.url) && !isJunkName(entry.name) &&
    isVietnamese(entry);
}

/**
 * Only HLS, and only straight from a CDN.
 *
 * The collection also gathers redirectors, file-sharing links and web pages
 * that happen to mention a channel. None of those is a stream, and a checker
 * that followed them would spend its budget finding that out.
 */
function isPlayableStream(url: string): boolean {
  const path = url.split("?")[0].toLowerCase();
  if (!path.startsWith("http") || !path.endsWith(".m3u8")) return false;
  return !JUNK_HOST.test(url);
}

const JUNK_HOST =
  /(short\.gy|dropbox|mediafire|iplogger|youtube\.com|youtu\.be|github\.com|githubusercontent|zmdcdn|\.php)/i;

/**
 * Bookkeeping the scraper leaves in a name — the file it read, the batch it
 * came from, a login page, a spare feed — and radio, which is not television.
 */
const JUNK_NAME =
  /(\.done|\.ref-|\?dl=|_kkk|\.m3u|http|login|\bkey\b|\bradio\b|\bvov\b|\btest\b|backup|intro|zalo|du phong|bao tri)/i;

function isJunkName(name: string): boolean {
  const trimmed = name.trim();
  return trimmed === "" || trimmed.startsWith("$") ||
    JUNK_NAME.test(foldAccents(name));
}

/**
 * Whether the entry really is a Vietnamese channel.
 *
 * A `tvg-id` names the country outright and settles it. Without one, the name
 * has to read as Vietnamese — a national network, a province, or simply a
 * name spelled with Vietnamese accents.
 */
function isVietnamese(entry: Entry): boolean {
  // Ahead of the `tvg-id`, which is where these are mislabelled in the first
  // place: `Tea TV` and `Uniquely Thai` are both published as `.vn`.
  if (FOREIGN_NAME.test(foldAccents(entry.name))) return false;

  const country = /^[^.]+\.([a-z]{2})(?:@.*)?$/i.exec(entry.id)?.[1];
  if (country) return country.toLowerCase() === "vn";

  // A shelf is worth reading when it names somebody else: `ANTV` is
  // Vietnam's police channel and also one of Indonesia's biggest stations,
  // and the only thing telling those two entries apart is that one of them
  // sits under `INDONESIA SD`.
  if (entry.groups.some((group) => FOREIGN_GROUP.test(foldAccents(group)))) {
    return false;
  }

  // A name in another script is another country's channel, whatever bucket
  // the collection filed it under. Read off the untouched name, because the
  // script is usually inside the brackets the parser drops.
  if (FOREIGN_SCRIPT.test(entry.rawName)) return false;

  // Past that the name alone, never the group: a shelf that claims Vietnam
  // is broad enough that a `VIETNAM TV24` bucket holds channels from
  // anywhere.
  const name = foldAccents(entry.name);
  if (FOREIGN_NAMESAKE.test(name)) return false;
  if (NETWORK.test(name) || PROVINCE.test(name)) return true;
  return name !== entry.name.toLowerCase();
}

/**
 * Other countries' channels that read as a Vietnamese network.
 *
 * `VTV` is Vietnam's national broadcaster, and also Indonesia's channel, the
 * Maldives', Uruguay's and Chile's; `SCTV` is Vietnam's cable network and
 * also one of Indonesia's biggest stations. Every one of those foreign
 * namesakes is called just that, where the Vietnamese channel always carries
 * a number or a province after it. So the bare name belongs to somebody else.
 */
const FOREIGN_NAMESAKE = /^(vtv|sctv)( ?hd| ?sd)?$/;

/**
 * Channels of other countries the playlists file under Vietnam anyway.
 *
 * Both lists carry a handful of stations serving the Thai, Khmer, Hmong and
 * Lao communities, and one American city council channel that reads as `HTV`
 * — some of them even labelled `.vn`. Nothing in the entry gives them away,
 * so they are named here. The word only has to start a word, because the
 * collection writes `KhmerTV` with nothing in between.
 */
const FOREIGN_NAME =
  /\b(hmong|khmer|houston|uniquely thai|lao[ -]?thai|tea tv)/;

/**
 * A group title that says the channel is another country's.
 *
 * The shelves the collection claims Vietnam with are broad enough to hold
 * anything — a `VIETNAM TV24` bucket has channels from everywhere — but a
 * shelf named after somebody else is only ever theirs. `nasional` is how the
 * Indonesian lists label their own national channels.
 */
const FOREIGN_GROUP =
  /\b(indonesia|nasional|malaysia|thailand|philippines|singapore|cambodia|myanmar|laos|india|china|korea|japan)\b/;

/** A letter from a script other than the Latin one Vietnamese is written in. */
const FOREIGN_SCRIPT = /[^\P{L}\p{Script=Latin}]/u;

const NETWORK =
  /^on\s|\b(vtv\w*|htv\w*|sctv\w*|vtc\w*|thvl\w*|vtvcab|antv|qpvn|quoc hoi|nhan dan|hanoicab|viet ?nam|truyen hinh)\b/;

/** The provinces and cities a local station is named after. */
const PROVINCE_WORDS = [
  "an giang",
  "ba ria",
  "vung tau",
  "bac giang",
  "bac kan",
  "bac lieu",
  "bac ninh",
  "ben tre",
  "binh dinh",
  "binh duong",
  "binh phuoc",
  "binh thuan",
  "ca mau",
  "can tho",
  "cao bang",
  "da nang",
  "dak lak",
  "dak nong",
  "dien bien",
  "dong nai",
  "dong thap",
  "gia lai",
  "ha giang",
  "ha nam",
  "ha noi",
  "hanoi",
  "ha tinh",
  "hai duong",
  "hai phong",
  "hau giang",
  "ho chi minh",
  "hoa binh",
  "hue",
  "hung yen",
  "khanh hoa",
  "kien giang",
  "kon tum",
  "lai chau",
  "lam dong",
  "lang son",
  "lao cai",
  "long an",
  "nam dinh",
  "nghe an",
  "ninh binh",
  "ninh thuan",
  "phu tho",
  "phu yen",
  "quang binh",
  "quang nam",
  "quang ngai",
  "quang ninh",
  "quang tri",
  "soc trang",
  "son la",
  "tay ninh",
  "thai binh",
  "thai nguyen",
  "thanh hoa",
  "thua thien",
  "tien giang",
  "tra vinh",
  "tuyen quang",
  "vinh long",
  "vinh phuc",
  "yen bai",
];
const PROVINCE = new RegExp(`\\b(${PROVINCE_WORDS.join("|")})\\b`);

/** The same places with the spaces taken out, as a key spells them. */
const PROVINCE_KEYS = PROVINCE_WORDS.map((p) => p.replace(/ /g, "")).join("|");

/**
 * Trims a collected name down to the channel.
 *
 * Local stations are listed under the name of the broadcaster that runs them
 * — `LTV1 | Báo và Phát thanh – Truyền hình Lâm Đồng` — which is a sentence
 * where the grid wants a label. Dropping the boilerplate leaves the call sign
 * and the province, which is what the channel is called on air, and it is
 * also what makes two spellings of one station collide in [dedupeKey].
 */
export function cleanVietnameseName(name: string): string {
  let cleaned = name;
  for (const boilerplate of BOILERPLATE) {
    cleaned = cleaned.replace(boilerplate, " ");
  }
  cleaned = cleaned
    .replace(/[|_–—]/g, " ")
    .replace(/\s+-\s+/g, " ")
    .replace(/\s+/g, " ")
    .replace(/^[\s.,-]+|[\s.,-]+$/g, "");
  cleaned = dropRepeatedTail(cleaned);
  return cleaned === "" ? name.trim() : cleaned;
}

/** Every accented letter Vietnamese is written with, upper and lower case. */
const VOWELS =
  "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ" +
  "ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ";

/**
 * [pattern] where a Vietnamese word starts and ends.
 *
 * `\b` cannot say that: it counts `ơ` as a boundary like any other character
 * outside ASCII, so a plain `\bTH\b` cuts the `Th` out of `Cần Thơ`.
 */
const word = (pattern: string) =>
  new RegExp(`(?<![A-Za-z${VOWELS}])${pattern}(?![A-Za-z${VOWELS}])`, "gi");

/**
 * The ways the sources write "the broadcaster of", longest first so a phrase
 * is never half-removed by one of its own parts.
 */
const BOILERPLATE = [
  /Báo\s+và\s+Phát\s+thanh\s*[-–]\s*Truyền\s+hình/gi,
  /Đài\s+Phát\s+thanh\s*[-–]\s*Truyền\s+hình/gi,
  /Báo\s+và\s+Truyền\s+hình/gi,
  /Báo\s+và\s+PTTH/gi,
  /Đài\s+PTTH/gi,
  word("PTTH"),
  /Truyền\s+hình/gi,
  /Thành\s+phố/gi,
  /Trung\s+tâm\s+truyền\s+thông/gi,
  word("TH\\.?"),
  word("TP\\.?"),
  // The resolution belongs in its own column, and leaving it in the label is
  // what makes two spellings of one station look like two stations.
  word("(?:HD|SD|FHD|UHD|4K)"),
];

/**
 * Drops a tail that only repeats what the name already said.
 *
 * A collected name often ends in the broadcaster it belongs to — `Cần Thơ 1
 * Thành Phố Cần Thơ` once the boilerplate is gone — which leaves the province
 * in there twice. Removing the repeat is what leaves `Cần Thơ 1`.
 */
function dropRepeatedTail(name: string): string {
  let words = name.split(" ").filter((w) => w !== "");
  const folded = words.map(foldAccents);

  // Longest repeat first: a two-word province has to go as a pair, or its
  // halves get matched one at a time against the wrong places.
  for (let length = 3; length >= 1; length--) {
    while (words.length > length * 2) {
      const tail = folded.slice(folded.length - length);
      if (!containsRun(folded.slice(0, folded.length - length), tail)) break;
      words = words.slice(0, words.length - length);
      folded.length = folded.length - length;
    }
  }
  return words.join(" ");
}

/** Whether [run] appears in [words] as consecutive entries. */
function containsRun(words: string[], run: string[]): boolean {
  for (let start = 0; start + run.length <= words.length; start++) {
    if (run.every((value, i) => words[start + i] === value)) return true;
  }
  return false;
}

/**
 * The name reduced to what makes one channel a different channel.
 *
 * Two playlists rarely spell a station the same way — `THVL1 HD`, `THVL1 HD |
 * Vĩnh Long`, `Kênh THVL1` — so the comparison drops the accents, the
 * resolution badge and the words every Vietnamese channel name carries, and
 * keeps the letters and digits that are left.
 */
export function dedupeKey(name: string): string {
  let key = foldAccents(name);
  for (const [spelling, callSign] of CALL_SIGN_ALIAS) {
    key = key.replace(spelling, callSign);
  }
  return key
    .replace(/\([^)]*\)/g, " ")
    .replace(/\[[^\]]*\]/g, " ")
    .replace(/\b(hd|sd|fhd|uhd|4k|tv|kenh|channel|dai|truyen hinh)\b/g, " ")
    .replace(/[^a-z0-9]/g, "")
    // `CanThoTV1` and `Can Tho 1` are one channel. Three letters have to
    // come first, or the `TV` of `HTV1` would be filed off too and the
    // station would collide with whatever else is called `H1` — and `ANTV`,
    // where the `TV` is part of the call sign, would come out as `AN`.
    .replace(/(?<=[a-z]{3})tv(?=\d|$)/, "")
    // A tail of three or more characters the key already contains, which is
    // the province said twice: `HanoiTV1 Hà Nội` keys as `hanoi1hanoi`.
    .replace(/(?<=(\w{3,})\w*)\1$/, "")
    // The same thing with nothing in between, which is what a name that
    // gives the call sign and then spells it out comes to: `QPVN Quốc
    // Phòng` is `qpvnqpvn` once the spelling is folded onto the sign, and
    // `Cần Thơ THTPCT` is `canthocantho1` with the station number behind it.
    .replace(/^(\w{3,})\1(\d*)$/, "$1$2");
}

/**
 * Call signs the sources are as likely to spell out as to abbreviate.
 *
 * `ANTV` is `An Ninh TV`, the police channel, and it is written both ways —
 * and once as `Vietnam ANTV`. `QPVN` is `Quốc Phòng Việt Nam`, and the
 * sources manage four spellings of it, two of which say it twice over.
 * Nothing the keys are built from makes them look alike, so without this
 * each spelling is a channel of its own.
 */
const CALL_SIGN_ALIAS: [RegExp, string][] = [
  [/\ban ninh\b/g, "antv"],
  [/\bcong an nhan dan\b/g, "antv"],
  [/\bquoc phong( viet ?nam| vn)?\b/g, "qpvn"],
  [/\bviet ?nam (antv|qpvn|vtc|vtv|htv)\b/g, "$1"],
  // `THVL` is `Truyền hình Vĩnh Long`, and the number that follows is the
  // station: `THVL5` is `Vĩnh Long 5`.
  [/\bthvl(?=\d)/g, "vinh long "],
  // `VTV5` broadcasts a region at a time, and the regions are abbreviated
  // as often as they are written out.
  [/\bvtv5 ?tnb\b/g, "vtv5 tay nam bo"],
  [/\bvtv5 ?tn\b/g, "vtv5 tay nguyen"],
  // `Cần Thơ`'s own station, whose call sign stands for the city it is
  // named after, so that every spelling of it says the city twice.
  [
    /\b(can tho tv(?! ?\d)|can tho thtpct|thtpct ?1? ?can tho ?1?)\b/g,
    "can tho 1",
  ],
  // The sports and the travel channel of Ho Chi Minh City's network, which
  // the sources name in two languages and at three lengths.
  [/\bhtvc? ?(sports?|the thao)\b/g, "htv the thao"],
  [/\bdu lich (va )?cuoc song\b/g, "du lich"],
  [/\bdramas\b/g, "drama"],
];

/**
 * Every key one channel could be known by, its own first.
 *
 * A local station goes by three names at once: its call sign, the province it
 * broadcasts to, and the two together. `DRT Đắk Lắk`, `Đắk Lắk` and `DRT` are
 * one channel, and `THVL1`, `THVL1 Vĩnh Long` and `Vĩnh Long 1` are another.
 * Two names are the same channel when any of their keys meet.
 */
export function identityKeys(name: string): Set<string> {
  const key = dedupeKey(name);
  const parts = CALL_SIGN.exec(key);
  if (!parts) return new Set([key]);

  const [, sign, beforeProvince, province, afterProvince] = parts;
  // A name that numbers the call sign one way and the province another is not
  // saying which station it means, so it is only ever itself.
  if (beforeProvince && afterProvince && beforeProvince !== afterProvince) {
    return new Set([key]);
  }
  // The number is the station's, wherever the name puts it: `LTV1 Lâm Đồng`
  // writes it before the province and `Lâm Đồng 1` after.
  const number = beforeProvince || afterProvince;

  // A national network in front of a province names a regional station of
  // that network, not the province's own: `VTV Cần Thơ` is not `Cần Thơ`.
  // Once there is a number that stops being true — `THVL1 Vĩnh Long` is
  // `Vĩnh Long 1` — because the number is what picks out the station.
  if (number === "" && NATIONAL_NETWORKS.has(sign)) return new Set([key]);

  return new Set([key, `${sign}${number}`, `${province}${number}`]);
}

/**
 * A key that reads as a call sign, a station number and a province in the
 * order a playlist happens to have written them.
 */
const CALL_SIGN = new RegExp(`^([a-z]+)([0-9]*)(${PROVINCE_KEYS})([0-9]*)$`);

/**
 * The networks that broadcast nationally, whose name in front of a province
 * says which of their own stations this is.
 */
const NATIONAL_NETWORKS = new Set([
  "vtv",
  "htv",
  "sctv",
  "vtc",
  "vtvcab",
  "antv",
  "qpvn",
]);

/**
 * [sources] best first, and no more of them than the checker will work
 * through before it accepts the channel is off the air.
 */
export function rankSources(sources: string[]): string[] {
  const ordered = [...new Set(sources)];
  return ordered
    .map((url, index) => ({
      url,
      index,
      host: sourceRank(url),
      rendition: renditionRank(url),
    }))
    .sort((a, b) =>
      a.host - b.host || a.rendition - b.rendition || a.index - b.index
    )
    .slice(0, MAX_SOURCES)
    .map((entry) => entry.url);
}

const MAX_SOURCES = 4;

/**
 * How good a picture the link says it serves, lowest first.
 *
 * A CDN often publishes one link per rendition beside the adaptive master —
 * `playlist1080p.m3u8` next to `playlist480p.m3u8`. All of them play, so
 * nothing else here tells them apart, and the channel then opens on
 * whichever the playlist wrote first: TVB Vietnam opened on 480p.
 *
 * The master is left in the middle rather than on top. It is the better
 * stream in principle, because the player can climb and fall with the line
 * — but these masters list their renditions smallest first, and a player
 * with no idea of the bandwidth yet starts on the first one, which on a
 * television is a 360p picture on a very large screen.
 */
function renditionRank(url: string): number {
  const named = /(\d{3,4})p(?![a-z0-9])/i.exec(url.split("?")[0]);
  if (named === null) return 1;
  return Number(named[1]) >= 720 ? 0 : 2;
}

/** How much a stream is worth trying, lowest first. */
function sourceRank(url: string): number {
  let host: string;
  try {
    host = new URL(url).host.toLowerCase();
  } catch {
    return 3;
  }
  // A playlist committed to a repository is a copy of a link, taken on the
  // day someone ran the scraper. The origin it was copied from is still
  // there; this file is what is left when it is not.
  if (host.endsWith(".github.io")) return 2;
  // `play.m3u8?vid=51` is a proxy that looks the channel up, not a stream. It
  // works until whoever runs it stops paying for it.
  if (url.includes("?")) return 1;
  return 0;
}

/**
 * The `iptv-org` category a collected channel belongs to.
 *
 * The collection files its channels under the network that carries them —
 * `VTVcab`, `Địa phương` — which is not what the app's chips mean, so the
 * category is read off the name instead. Most local stations are general
 * channels and say nothing more about themselves.
 */
export function category(name: string): string {
  const text = foldAccents(name);
  for (const [label, pattern] of CATEGORIES) {
    if (pattern.test(text)) return label;
  }
  return "General";
}

const CATEGORIES: [string, RegExp][] = [
  ["Sports", /\b(the thao|sport|sports|bong da|football|golf)\b/],
  ["Kids", /\b(thieu nhi|kids|bibi|hoat hinh|cartoon|be yeu)\b/],
  ["Movies", /\b(phim|movie|movies|cine|drama|dramas)\b/],
  ["Music", /\b(am nhac|ca nhac|music)\b/],
  ["News", /\b(tin tuc|thoi su|news|antv)\b/],
  ["Shop", /\b(mua sam|shop|shopping|homeshopping|scj)\b/],
  ["Travel", /\b(du lich|travel)\b/],
  ["Cooking", /\b(am thuc|food|cooking)\b/],
  ["Education", /\b(giao duc|education)\b/],
];

/**
 * [value] with its Vietnamese vowels folded onto the letter they are built
 * from, lower cased, so the comparisons above can be written in plain ASCII.
 */
export function foldAccents(value: string): string {
  return value
    .toLowerCase()
    .replace(/đ/g, "d")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

/**
 * Orders two channel names the way a viewer reads them, which means the
 * digits in them count as numbers: plain text ordering puts `VTV10` between
 * `VTV1` and `VTV2`, and the national channels come out shuffled.
 *
 * What is compared is not the name as written but the name reduced to what a
 * viewer would say out loud. The two playlists spell one family of channels
 * every which way — `Vinh Long TV 4` beside `Vĩnh Long 5` — and both the
 * accents and the stray `TV` would otherwise break the family apart: every
 * accented letter sorts after `z` in code point order, which files
 * `Vĩnh Long 5` and `Đà Nẵng` past the end of the list, and the `TV` puts
 * whatever carries it after every number.
 */
export function compareChannelNames(first: string, second: string): number {
  const byReading = compareText(sortKey(first), sortKey(second));
  if (byReading !== 0) return byReading;
  // Two names that read the same still have to have an order between them.
  return compareText(foldAccents(first), foldAccents(second));
}

/**
 * The words a channel name carries without them saying which channel it is,
 * so that `Vĩnh Long 5` and `Vinh Long TV 4` sort as one run of numbers.
 */
const SORT_NOISE = /\b(tv|kenh|channel|hd|sd|fhd|uhd|4k)\b/g;

function sortKey(name: string): string {
  return foldAccents(name).replace(SORT_NOISE, " ").replace(/\s+/g, " ").trim();
}

function compareText(left: string, right: string): number {
  let i = 0;
  let j = 0;
  while (i < left.length && j < right.length) {
    if (isDigit(left[i]) && isDigit(right[j])) {
      let leftEnd = i;
      while (leftEnd < left.length && isDigit(left[leftEnd])) leftEnd++;
      let rightEnd = j;
      while (rightEnd < right.length && isDigit(right[rightEnd])) rightEnd++;

      // Leading zeros say nothing about the value, so `07` and `7` are the
      // same number and the longer run is only the bigger one after them.
      const leftNumber = withoutLeadingZeros(left.slice(i, leftEnd));
      const rightNumber = withoutLeadingZeros(right.slice(j, rightEnd));
      if (leftNumber.length !== rightNumber.length) {
        return leftNumber.length - rightNumber.length;
      }
      if (leftNumber !== rightNumber) {
        return leftNumber < rightNumber ? -1 : 1;
      }

      i = leftEnd;
      j = rightEnd;
      continue;
    }

    if (left[i] !== right[j]) return left[i] < right[j] ? -1 : 1;
    i++;
    j++;
  }

  // One name ran out first: it is the shorter of two that read the same so
  // far, and shorter comes first.
  return (left.length - i) - (right.length - j);
}

const isDigit = (c: string) => c >= "0" && c <= "9";

const withoutLeadingZeros = (digits: string) =>
  digits.replace(/^0+/, "") || "0";
