#!/bin/bash

set -e ## The script should stop on error
shopt -s extglob; ## Enables extglob extension to use rm !()

## HELPER FUNCTIONS
help_error() {
    if [ $# -gt 0 ]; then echo $1; fi
    echo 'Basic usage : bearbk-converter [options=] path/to/archive'
    echo 'Available options are :'
    echo '    --markdown to output .md files instead of .txt'
    echo '    -g --gitpath to specify the local path to a git repository to which the backed up data will be automatically moved, commited and pushed.'
    exit 1
}

is_set() {
    ! [ -z ${1+x} ]
}
is_directory() {
    [ -d "$1" ]
}

file_exists() {
    [ -f "$1" ]
}

## Ensuring external dependencies are available
type jq >/dev/null 2>&1 || { echo >&2 "Error : You should install 'jq' before you can run this script. Try 'brew install jq'."; exit 1; }
type bsdtar >/dev/null 2>&1 || { echo >&2 "Error : You should install 'bsdtar' before you can run this script. "; exit 1; }
type sed >/dev/null 2>&1 || { echo >&2 "Error : You should install 'sed' before you can run this script. "; exit 1; }

## Check arguments were provided
if [[ $# -eq 0 ]] ; then
    help_error 'Error : You have to specify the path to the Bear Archive.'
fi

## Serialize arguments
for i in "$@"
do
    case $i in
        -g=*|--gitpath=*)
        GITPATH="${i#*=}"
        shift # past argument=value
        ;;
        --markdown)
        IS_MARKDOWN=YES
        shift # past argument=value
        ;;
        *)
                # unknown option
        ;;
    esac
done

## Basic variable assignments and error checks
EXEC_LOCATION=`pwd`

#if is_set $GITPATH && ! is_directory "$GITPATH"/".git"; then help_error "Error : This is not a git repository"; fi

BW_ARCHIVE_ARGUMENT=$1
if ! file_exists $BW_ARCHIVE_ARGUMENT; then help_error "Error : Archive File Path is not valid"; fi

BW_ARCHIVE_LOCATION=$(dirname "$BW_ARCHIVE_ARGUMENT")
BW_ARCHIVE_FILE=$(basename "$BW_ARCHIVE_ARGUMENT")
BW_ARCHIVE_EXTENSION="${BW_ARCHIVE_FILE##*.}"
BW_ARCHIVE_FILENAME="${BW_ARCHIVE_FILE%.*}"

## Ensuring .bearbk files is passed as first argument.
if [ $BW_ARCHIVE_EXTENSION != "bearbk" ]; then
    echo "Error : You should specify a bear writer archive '.bearbk'";
    exit 1;
fi

## Ensuring passed file is a Zip archive.
if [[ `file "$BW_ARCHIVE_ARGUMENT"` != *"Zip"* ]]; then
  echo "Error : This is not a proper zip archive";
  exit 1;
fi

TMP_DIR_NAME="BEAR_BACKUP";

## Moving to the archive location
cd "$BW_ARCHIVE_LOCATION";

## Create temporary work directory or exit
mkdir $TMP_DIR_NAME 2>/dev/null || { echo "A folder named $TMP_DIR_NAME already exists. Abording."; exit 1; }

## Unzip the archive content in temporary folder (without main container)
bsdtar -xf "$BW_ARCHIVE_FILE" -s'|[^/]*/||' -C $TMP_DIR_NAME;

for SUBFOLDER in $TMP_DIR_NAME/*; do
    [ -e "$SUBFOLDER" ] || continue;

    ## Exit if not expected files
    [ ! -e "$SUBFOLDER"/"info.json" ] && echo "Error : The file info.json doesn't exist" && exit 1;
    [ ! -e "$SUBFOLDER"/"text.txt" ] && echo "Error : The file text.txt doesn't exist" && exit 1;

    ## Skip if trashed
    IS_TRASHED=$(cat "$SUBFOLDER""/info.json" | jq '.["net.shinyfrog.bear"].trashed' );
    if [ $IS_TRASHED == "null" ]; then echo "Unable to trash variable. Abording."; exit 1; fi;
    if [ $IS_TRASHED == "1" ]; then echo "trashed"; rm -rf "$SUBFOLDER"; continue; fi;

    ## Get file's infos
    TITLE=$(basename "${SUBFOLDER%.*}");
    MODIFICATION_DATE=$(cat "$SUBFOLDER""/info.json" | jq '.["net.shinyfrog.bear"].modificationDate' | sed -e 's/^"//' -e 's/"$//'); # Sed to get rid of quotes otherwise date doesn't work
    CREATION_DATE=$(cat "$SUBFOLDER""/info.json" | jq '.["net.shinyfrog.bear"].creationDate' | sed -e 's/^"//' -e 's/"$//');

    ## Reformat dates for passing to "touch"
    MOD_DATE_REFORMATED=$(date -j -f %Y-%m-%dT%H:%M:%S%z $MODIFICATION_DATE +%Y%m%d%H%M);
    CREA_DATE_REFORMATED=$(date -j -f %Y-%m-%dT%H:%M:%S%z $CREATION_DATE +%Y%m%d%H%M);

    ## Set Creation and Modification dates
    touch -t $CREA_DATE_REFORMATED "$SUBFOLDER""/text.txt"; # Changes both creation date and modification date
    touch -t $MOD_DATE_REFORMATED "$SUBFOLDER""/text.txt"; # Changes only modificaiton date

    ## Prepare file extension
    if is_set $IS_MARKDOWN; then FILE_EXTENSION="md"; else FILE_EXTENSION="txt"; fi

    ## In case the file has image
    if is_directory "$SUBFOLDER"/assets; then
        ## Rename file
        mv "$SUBFOLDER"/"text.txt" "$SUBFOLDER"/"$TITLE".$FILE_EXTENSION
        ## Create wrapper folder
        mkdir "$TMP_DIR_NAME"/"$TITLE"
        ## Move files into the new folder
        mv "$SUBFOLDER"/* "$TMP_DIR_NAME"/"$TITLE"
    else
        ## Rename and change location
        mv "$SUBFOLDER"/"text.txt" "$TMP_DIR_NAME"/"$TITLE".$FILE_EXTENSION
    fi
    ## Delete subfolder
    rm -rf "$SUBFOLDER";


done

## Go back to starting point
cd "$EXEC_LOCATION";

## Commit on Git
if is_set $GITPATH; then

    ## Started to throw "fts_read: no such file or directory errors"
    ## find "$GITPATH"/* -not -name ".git" -exec rm -rf "{}" +

    cd "$GITPATH";
    shopt -s extglob; # Needed to use !() synthax
    rm -rf -- !(".git");
    cd "$EXEC_LOCATION";

    cp -rf "$BW_ARCHIVE_LOCATION"/"$TMP_DIR_NAME"/* "$GITPATH"

    cd "$GITPATH";
    git add -A;
    git commit -m"Update `date +%Y-%m-%d`";
    cd "$EXEC_LOCATION";
    rm -R "$BW_ARCHIVE_LOCATION"/"$TMP_DIR_NAME"

fi

exit
