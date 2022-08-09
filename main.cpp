#include <bits/stdc++.h>
using namespace std;

int main() {
    int n, k;
    cin >> n >> k;

    const auto between_ps = [](int y1, int x1, int y2, int x2) -> vector<pair<int, int>> {
        int y = y1, x = x1;
        int dy = y2 - y1;
        int dx = x2 - x1;
        dy = dy == 0 ? 0 : (dy > 0 ? 1 : -1);
        dx = dx == 0 ? 0 : (dx > 0 ? 1 : -1);

        vector<pair<int, int>> ret;
        while (y + dy != y2 or x + dx != x2) {
            ret.push_back({y + dy, x + dx});
            x += dx;
            y += dy;
        }

        return ret;
    };

    vector<vector<int>> field(n, vector<int>(n));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            char c;
            cin >> c;
            field[i][j] = c - '0';
        }
    }

    cout << 0 << endl;

    using P = pair<int, int>;
    vector<vector<bool>> is_used(n, vector<bool>(n, false));
    vector<pair<P, P>> connected;

    const auto connect = [&](int y1, int x1, int y2, int x2) -> bool {
        for (auto [y, x] : between_ps(y1, x1, y2, x2)) {
            if (is_used[y][x]) return false;
            is_used[y][x] = true;
        }
        connected.push_back({{y1, x1}, {y2, x2}});
        return true;
    };

    for (int x = 0; x < n; x++) {
        int prev_y = -1;
        for (int y = 0; y + 1 < n; y++) {
            if (prev_y == -1) {
                if (field[y][x] > 0) prev_y = y;
                continue;
            }
            if (field[y][x] > 0) {
                if (field[y][x] == field[prev_y][x]) {
                    connect(y, x, prev_y, x);
                }
                prev_y = y;
            }
        }
    }

    for (int y = 0; y < n; y++) {
        int prev_x = -1;
        for (int x = 0; x + 1 < n; x++) {
            if (prev_x == -1) {
                if (field[y][x] > 0) prev_x = x;
                continue;
            }
            if (field[y][x] > 0) {
                if (field[y][x] == field[y][prev_x]) {
                    connect(y, x, y, prev_x);
                }
                prev_x = x;
            }
        }
    }
    cout << connected.size() << endl;
    for (auto [p1, p2] : connected) {
        cout << p1.first << " " << p1.second << " " << p2.first << " " << p2.second << endl;
    }
}