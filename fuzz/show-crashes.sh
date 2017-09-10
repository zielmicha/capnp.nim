for i in fuzz/out/crashes/*; do
    echo "file $i"
    ./fuzz/rpc-debug < $i
done
