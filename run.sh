./build.sh

./main.o < in/0000.txt > out/0000.txt

cat in/0000.txt out/0000.txt > tmp && ./tester.o < tmp && rm tmp
