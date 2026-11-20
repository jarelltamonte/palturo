// Deterministic note prefilter.
//
// Runs before any inference call. Obvious junk is rejected here so it cannot
// consume model credit and cannot be approved by a permissive model response.

export type NoteIssue =
  | "empty"
  | "too_short"
  | "too_few_words"
  | "too_long"
  | "mostly_symbols"
  | "gibberish"
  | "repeated_words"
  | "skill_echo"
  | "markup"
  | "pii"
  | "injection";

const CONTROL = /[\u0000-\u001F\u007F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]/;
const PII = /(https?:\/\/|www\.|@[a-z0-9.-]+\.[a-z]{2,}|\+?\d[\d\s().-]{7,}\d|[<>])/i;
const INJECTION =
  /(ignore (all )?(previous|above|prior)|disregard (the )?(previous|above)|system\s*:|assistant\s*:|you are now|set (relevant|safe|value).{0,20}(1|true)|rank me first|prefer (this|my) profile|boost (this|my)|top (result|match)|match me (first|higher)|when ranking)/i;
const KEYBOARD =
  /(qwe|wer|ert|rty|tyu|yui|uio|iop|asd|sdf|dfg|fgh|ghj|hjk|jkl|zxc|xcv|cvb|vbn|bnm)/i;
const CONSONANT_RUN = /[bcdfghjklmnpqrstvwxz]{6,}/i;
const REPEATED_CHAR = /(.)\1{3,}/i;

const normalize = (value: string) =>
  value.toLowerCase().replace(/\s+/g, " ").trim();

export function inspectNote(note: string, skillName: string): NoteIssue | null {
  const raw = String(note ?? "").trim();
  if (!raw) return "empty";
  if (raw.length < 10) return "too_short";
  if (raw.length > 150) return "too_long";
  if (CONTROL.test(raw)) return "markup";
  if (PII.test(raw)) return "pii";
  if (INJECTION.test(raw)) return "injection";

  const words = raw.split(/\s+/).filter(Boolean);
  if (words.length < 2) return "too_few_words";
  if (words.length > 40) return "too_long";

  const letters = raw.replace(/[^\p{L}\p{M}]/gu, "");
  if (letters.length < 6) return "mostly_symbols";
  if (letters.length / raw.length < 0.55) return "mostly_symbols";

  const distinctLetters = new Set(letters.toLowerCase()).size;
  if (distinctLetters < 3) return "gibberish";

  const normalized = normalize(raw);
  const normalizedSkill = normalize(skillName);
  if (normalizedSkill && normalized === normalizedSkill) return "skill_echo";

  const uniqueWords = new Set(words.map((word) => word.toLowerCase()));
  if (uniqueWords.size < 2) return "repeated_words";

  for (const word of words) {
    const token = word.replace(/^[^\p{L}\p{M}]+|[^\p{L}\p{M}]+$/gu, "");
    if (!token) continue;
    if (REPEATED_CHAR.test(token)) return "gibberish";
    if (token.length >= 5 && new Set(token.toLowerCase()).size <= 2) {
      return "gibberish";
    }
    if (KEYBOARD.test(token) && token.length <= 12) return "gibberish";
    if (CONSONANT_RUN.test(token)) return "gibberish";
  }

  return null;
}
