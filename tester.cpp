#include <bits/stdc++.h>
#include <atcoder/dsu>
using namespace std;

void error(string s) {
    cout << s << endl;
    exit(1);
}

int main() {
    // read input
    int n, k;
    cin >> n >> k;

    const auto in_field = [&n](int y, int x) -> bool {
        return 0 <= y and y < n and 0 <= x and x < n;
    };
    const auto is_valid_move = [](int y1, int x1, int y2, int x2) -> bool {
        return abs(y1 - y2) + abs(x1 - x2) == 1;
    };
    const auto idx = [&n](int y, int x) -> int {
        return y * n + x;
    };
    const auto is_valid_connect = [](int y1, int x1, int y2, int x2) -> bool {
        return (abs(y1 - y2) > 0) ^ (abs(x1 - x2) > 0);
    };
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

    // read output
    int x;
    cin >> x;
    for (int i = 0; i < x; i++) {
        int a, b, c, d;
        cin >> a >> b >> c >> d;
        // cerr << "move: " << a << " " << b << " " << c << " " << d << endl;
        // (a, b) -> (c, d)

        if (field[a][b] == 0)
            error("Invalid move. No computer.");
        if (field[c][d] != 0)
            error("Invalid move. Computer exists.");
        if (!is_valid_move(a, b, c, d))
            error("Invalid move. Not adjacent.");
        if (!in_field(a, b) || !in_field(c, d))
            error("Invalid move. Not in field.");

        swap(field[a][b], field[c][d]);
    }

    vector<bool> is_used(n * n, false);
    atcoder::dsu uf(n * n);
    set<pair<int, int>> connected;

    int y;
    cin >> y;
    for (int i = 0; i < y; i++) {
        int e, f, g, h;
        cin >> e >> f >> g >> h;
        // cerr << "connect: " << e << " " << f << " " << g << " " << h << endl;
        // (e, f) - (g, h)

        if (!is_valid_connect(e, f, g, h))
            error("Invalid connect. Not aligned.");
        if (field[e][f] == 0 or field[g][h] == 0)
            error("Invalid connect. No computer.");

        int p1 = idx(e, f), p2 = idx(g, h);
        if (p1 == p2)
            error("Invalid connect. Selecting same computer.");
        if (connected.find({min(p1, p2), max(p1, p2)}) != connected.end())
            error("Invalid connect. Already connected.");

        connected.insert({min(p1, p2), max(p1, p2)});
        uf.merge(p1, p2);

        vector<pair<int, int>> between_p = between_ps(e, f, g, h);

        for (auto [y, x] : between_p) {
            if (field[y][x] > 0)
                error("Invalid connect. Computer exist between.");
            if (is_used[idx(y, x)])
                error("Invalid connect. Cable exist already.");
            is_used[idx(y, x)] = true;
        }
    }

    vector<pair<int, int>> v;
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            if (field[i][j] > 0) v.push_back({idx(i, j), field[i][j]});
        }
    }

    int score = 0;

    for (int i = 0; i < v.size(); i++) {
        for (int j = 0; j < i; j++) {
            auto [pi, ci] = v[i];
            auto [pj, cj] = v[j];

            if (uf.same(pi, pj)) {
                if (ci == cj)
                    score++;
                else
                    score--;
            }
        }
    }

    cout << "Score=" << score << endl;

    return 0;
}