# Verification

October 2, 2026:

- Three Debug and Release core tests passed on macOS 27.
- The original synthetic linear DNG decoded through CIRAWFilter, previewed, saved/reopened, and exported as JPEG. Original bytes were unchanged; a stale recipe revision was rejected.
- Mac and iPad Simulator Release builds passed.
- Native Mac UI workflow compiled. Hosted execution is pending.

The synthetic fixture does not validate real camera sensor decoding or color accuracy. Physical-iPad interaction, Apple Pencil behavior, VoiceOver, extended text sizes, and a representative camera RAW collection still need manual verification. New-camera decoder resource availability also depends on the installed system.
