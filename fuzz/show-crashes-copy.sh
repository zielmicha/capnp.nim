for i in fuzz/out-copy/crashes/*; do
    echo "file $i"
    ./fuzz/copy-debug < $i
done
