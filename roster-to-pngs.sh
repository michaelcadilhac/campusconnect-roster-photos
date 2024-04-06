#!/bin/zsh -f

PROG=$0

usage () {
    cat <<EOF
usage: $PROG ROSTER.PDF ROSTER.CSV

This scripts reads ROSTER.PDF and extracts the name, UID, and photo of each
student.  The resulting database is stored in ROSTER.CSV.  The photos are saved
as PNG files in the current directory.

Dependencies: pdfimages and pdftotext (from poppler).
EOF
    exit 2
}

(( $# == 2 )) || usage
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

rm -f $2 || die "cannot delete $2."

photodir=$(mktemp -d)
echo "running pdfimages..."
pdfimages -png $1 $photodir/photo || die "pdfimages failed."

photoid=0
pdftotext -bbox-layout $1 - | while readuntil '.</word>'; do
    echo -n "\rprocessing student #$(content $line)"
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
    (( photoid ++))
    mv $photodir/photo-${(l(3)(0))photoid}.png $id.png || exit 3
    echo $id:$name:$id.png >> $2
done

echo " all done."
rm -rf $photodir
