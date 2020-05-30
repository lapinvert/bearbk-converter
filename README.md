# Bearbk Converter

`bearbk-converter` is a quick utility that allows you to convert Bear Writer's backup files ".bearbk" into folder including all your notes as ".txt" or ".md" files, with correct creation/modification dates.

For those of you who want to be able to keep track of your files' history, `bearbk-converter` can also automatically version your notes with git.

## Dependencies

- jq -> Install with `brew install jq`

## Global Installation

```
cp bearbk-converter.sh /usr/local/bin/bearbk-converter
chmod +x /usr/local/bin/bearbk-converter
```

## Basic Usage

Global usage : `bearbk-converter path/to/backup.bearbk`

Local usage :  `bash bearbk-converter.sh path/to/backup.bearbk`

This will output a "BEAR_BACKUP" folder next to the archive, including all your notes as .txt, with correct creation date and modification dates.

**Warning** : It WON'T work if there is spaces in path and/or bearbk archive file name. You may have to rename it to make it work. See known limitations.

## Options

`--markdown` : To output ".md" files instead of ".txt" files

`--gitpath=/path/to/gitfolder` : Instead of creating a BEAR_BACKUP folder, it will move all your converted notes into the local git repository provided, and perform an automatic commit. Commit name will look like "Update 20170308" (with current date of course).

## Example

`bearbk-converter --markdown --gitpath=/path/to/gitfolder /path/to/archive.bearbk`

## Tested environments

- MAC OS 10.11.6, bash 3.2

## Known Limitations

- Do not work when there is space in archive name.
- Final file names after conversion may include a number at the end, if there was an identical filename within the trash.
- Image links are broken and we should replace `[assets/file]` by `![](assets/file)` to make it work in any MarkDown reader.

## Your help is needed

Let me know your thoughts. Please fill an issue if you find one, or request changes, or help me maintaining it.

- Deploying the script in and/or npm homebrew for easy install
- For testing in more environments
- For being able to take tags into account and maybe separate notes by tags
