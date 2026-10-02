# Verification

October 2, 2026:

- Three Debug and Release core tests passed on macOS 27.
- The original synthetic linear DNG decoded through CIRAWFilter, previewed, saved/reopened, and exported as JPEG. Original bytes were unchanged; a stale recipe revision was rejected.
- Mac and iPad Simulator Release builds passed.
- [Hosted native workflow](https://github.com/DawoodAamir/RAW-Photo-Studio/actions/runs/36946341272) passed. Importing a DNG, adjusting and saving its recipe, and reopening the saved project passed.

The synthetic fixture does not validate real camera sensor decoding or color accuracy. Physical-iPad interaction, Apple Pencil behavior, VoiceOver, extended text sizes, and a representative camera RAW collection still need manual verification. New-camera decoder resource availability also depends on the installed system.
