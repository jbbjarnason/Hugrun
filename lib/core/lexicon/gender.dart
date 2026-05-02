// Phase 10 D-06 — Pure-Dart lexicon. No package:flutter imports.

/// Icelandic grammatical gender for nouns. Used by [LexiconEntry] so future
/// passes can pick gender-correct number agreement (e.g. *einn hundur* /
/// *ein kýr* / *eitt hús*) when the lexicon feeds into the numeracy
/// activities (Phase 9 D-15).
///
/// Per PROJECT.md: at age 5 the app uses masculine for abstract counting
/// (school convention) and the depicted noun's gender for pictured-object
/// counting. The gender field exists so v2/Phase 9 polish can wire that up;
/// Phase 10's matching activity does not yet use it (matching is letter-only).
enum Gender { masculine, feminine, neuter }
