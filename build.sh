echo "[LOG] Compile tester.cpp..."
g++-11 tester.cpp --std=c++17 -o tester.o

if [[ $1 == "cpp" ]]; then
echo "[LOG] Compile main.cpp..."
g++-11 -std=c++17 main.cpp -o main.o
else
echo "[LOG] Combinate files..."

python3 comb.py

echo "[LOG] Output file: out/main.swift"
echo "[LOG] Compile out/main.swift..."
swiftc out/main.swift -o main.o
fi

echo "[LOG] Compile done. -> main.o"