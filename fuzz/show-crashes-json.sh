for i in fuzz/json-out/crashes/*; do
    echo "file $i"
    ./fuzz/json-debug < $i
done
