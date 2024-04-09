#!/bin/zsh -f

PROG=$0

usage () {
    cat <<EOF
usage: $PROG ROSTER.PDF [ROSTER.PDF...] ROSTER.CSV

This scripts reads one or more ROSTER.PDF and extracts the name, UID, and photo
of each student.  The resulting database is stored in ROSTER.CSV.  The photos
are saved as JPEG files in the current directory.

Dependencies: pdfimages and pdftotext (from poppler).
EOF
    exit 2
}

(( $# >= 2 )) || usage

for dep in pdftotext pdfimages; do
    if ! which $dep &> /dev/null; then
        echo "error: missing dependency $dep"
        usage
    fi
done

readuntil () {
    while { read line || return 1 } && [[ ! $line == *"$1"* ]]; do
        :
    done
    return 0
}

content () {
    sed 's/.*>\(.*\)<.*/\1/' <<< $1
}

die () {
    echo "${1:-error: unexpected contents.}"
    exit 2
}

CSV="${@: -1}"

rm -f $CSV || die "cannot delete $CSV."

photodir=$(mktemp -d)

if (( $# > 2 )); then
    echo "concatenating PDFs..."
    pdf=$photodir/roster.pdf
    pdftk "${@[@]:1:-1}" cat output $pdf
else
    pdf=$1
fi

echo "running pdfimages..."
pdfimages -j $pdf $photodir/photo || die "pdfimages failed."

photoid=0
pdftotext -bbox-layout $pdf - | while readuntil '.</word>'; do
    echo -n "\rprocessing student #$photoid"
    # Jumps to the first word after the number id.
    readuntil '<word' || die
    id=$(content $line)
    readuntil '<word' || die
    name=""
    while [[ $line == *'<word'* ]]; do
        [[ $name ]] && name+=' '
        name="$name$(content $line)"
        read line || die
    done
    while :; do
        (( photoid ++))
        photo=$photodir/photo-${(l(3)(0))photoid}.jpg
        [[ -e $photo ]] && break
    done
    mv $photo $id.jpg || exit 3
    echo $id:$name:$id.jpg >> $CSV
done

echo " all done."
rm -rf $photodir
