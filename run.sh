FILE=$1

./main.o < in/$FILE.txt > out/$FILE.txt

cat in/$FILE.txt out/$FILE.txt | ./tester.o

pbcopy < out/$FILE.txt