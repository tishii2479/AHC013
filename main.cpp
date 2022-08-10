#include <bits/stdc++.h>

struct C {
    int type;
    int cable;
    int comp_idx;

    bool is_computer() { return type > 0; }
    bool is_cabled() { return cable > 0; }
    bool is_empty() { return !is_computer() and !is_cabled(); }
};

struct Pos {
    int y, x;

    Pos operator+=(Pos &rhs) {
        (*this).y += rhs.y;
        (*this).x += rhs.x;
        return *this;
    }

    friend std::ostream &operator<<(std::ostream &os, Pos &pos) {
        os << "(" << pos.y << ", " << pos.x << ")";
        return (os);
    }
};

struct Comp {
    int type;
    Pos pos;
};

Pos operator+(Pos &lhs, Pos &rhs) {
    return {lhs.y + rhs.y, lhs.x + rhs.x};
}

const Pos up = {-1, 0};
const Pos down = {1, 0};
const Pos left = {0, -1};
const Pos right = {0, 1};

const std::vector<Pos> dirs = {up, down, left, right};

// Variables

clock_t start;
std::mt19937 mt;
std::random_device rnd;
int n, k;

std::vector<std::vector<C>> field;
std::vector<Comp> computers;

double elapsed_seconds() {
    return (double)(clock() - start) / CLOCKS_PER_SEC;
}

int rand(int l, int r) {
    return (mt() % (r - l)) + l;
}

bool is_valid_pos(Pos p) {
    return 0 <= p.y and p.y < n and 0 <= p.x and p.x < n;
}

void setup() {
    mt.seed(rnd());
    start = clock();
    std::cin >> n >> k;

    field.assign(n, std::vector<C>(n));

    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            char c;
            std::cin >> c;
            int type = c - '0';
            if (type > 0) {
                field[i][j] = {type, 0, (int)computers.size()};
                computers.push_back({type, {i, j}});
            } else {
                field[i][j] = {type, 0, -1};
            }
        }
    }
}

std::vector<Pos> between_ps(Pos p1, Pos p2) {
    auto [y1, x1] = p1;
    auto [y2, x2] = p2;
    int y = y1, x = x1;
    int dy = y2 - y1;
    int dx = x2 - x1;
    dy = dy == 0 ? 0 : (dy > 0 ? 1 : -1);
    dx = dx == 0 ? 0 : (dx > 0 ? 1 : -1);

    std::vector<Pos> ret;
    while (y + dy != y2 or x + dx != x2) {
        ret.push_back({y + dy, x + dx});
        x += dx;
        y += dy;
    }

    return ret;
}

std::vector<std::pair<Pos, Pos>> connect() {
    std::vector<std::pair<Pos, Pos>> connected;

    // reset cable
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            field[i][j].cable = 0;

    const auto connect = [&](Pos p1, Pos p2, int type) -> bool {
        for (auto [y, x] : between_ps(p1, p2)) {
            if (field[y][x].is_cabled() and field[y][x].cable != type) return false;
            field[y][x].cable = type;
        }
        connected.push_back({p1, p2});
        return true;
    };

    for (int x = 0; x < n; x++) {
        int prev_y = -1;
        for (int y = 0; y < n; y++) {
            if (prev_y == -1) {
                if (field[y][x].is_computer()) prev_y = y;
                continue;
            }
            if (field[y][x].is_cabled()) prev_y = -1;
            if (field[y][x].is_computer()) {
                if (field[y][x].type == field[prev_y][x].type) {
                    connect({y, x}, {prev_y, x}, field[y][x].type);
                }
                prev_y = y;
            }
        }
    }

    for (int y = 0; y < n; y++) {
        int prev_x = -1;
        for (int x = 0; x < n; x++) {
            if (prev_x == -1) {
                if (field[y][x].is_computer()) prev_x = x;
                continue;
            }
            if (field[y][x].is_cabled()) prev_x = -1;
            if (field[y][x].is_computer()) {
                if (field[y][x].type == field[y][prev_x].type) {
                    connect({y, x}, {y, prev_x}, field[y][x].type);
                }
                prev_x = x;
            }
        }
    }

    return connected;
}

int get_adjacent_computer(Pos pos, Pos dir) {
    Pos cur = pos + dir;

    while (is_valid_pos(cur)) {
        if (field[cur.y][cur.x].is_computer())
            return field[cur.y][cur.x].comp_idx;
        if (field[cur.y][cur.x].is_cabled())
            return -1;
        cur += dir;
    }

    return -1;
}

int get_cluster(int comp_idx, int pair_comp_idx = -1) {
    std::set<int> seen_comp;
    seen_comp.insert(comp_idx);

    std::queue<Pos> q;
    q.push(computers[comp_idx].pos);

    while (q.size()) {
        auto p = q.front();
        q.pop();

        for (Pos dir : dirs) {
            int adj_comp_idx = get_adjacent_computer(p, dir);
            if (adj_comp_idx == -1)
                continue;
            if (computers[adj_comp_idx].type != computers[comp_idx].type)
                continue;
            if (seen_comp.find(adj_comp_idx) != seen_comp.end())
                continue;

            // If found pair_comp_idx in the same cluster, return -1
            if (adj_comp_idx == pair_comp_idx)
                return -1;

            q.push(computers[adj_comp_idx].pos);
            seen_comp.insert(adj_comp_idx);
        }
    }

    std::cerr << seen_comp.size() << std::endl;
    for (int idx : seen_comp) std::cerr << computers[idx].pos << " ";
    std::cerr << std::endl;

    return seen_comp.size();
}

// TODO: Implement
int calc_score_diff(Pos from_pos, Pos to_pos) {
    return 0;
}

int main() {
    setup();

    std::vector<std::pair<Pos, Pos>> moves;

    const auto output = [&]() {
        std::cout << moves.size() << std::endl;
        for (auto [p1, p2] : moves) {
            std::cout << p1.y << " " << p1.x << " " << p2.y << " " << p2.x << std::endl;
        }

        auto connected = connect();

        std::cout << connected.size() << std::endl;
        for (auto [p1, p2] : connected) {
            std::cout << p1.y << " " << p1.x << " " << p2.y << " " << p2.x << std::endl;
        }

        std::cerr << "Total: " << moves.size() + connected.size() << ", moves: " << moves.size() << ", connect: " << connected.size() << std::endl;
    };

    const auto search_move = [&]() {
        int sum = 0;

        int comp_idx = rand(0, computers.size());
        Comp comp = computers[comp_idx];

        int base_score = 0;
        for (auto dir : dirs) {
            int adj_comp_idx = get_adjacent_computer(comp.pos, dir);
            if (adj_comp_idx == -1) continue;
            if (comp.type == computers[adj_comp_idx].type)
                base_score -= get_cluster(adj_comp_idx) - 1;
        }

        int best_score = 0;
        Pos best_pos = comp.pos;
        for (auto dir : dirs) {
            Pos next_pos = comp.pos + dir;
            if (!is_valid_pos(next_pos)) continue;
            if (!field[next_pos.y][next_pos.x].is_empty()) continue;

            int score = base_score;
            for (auto dir : dirs) {
                int adj_comp_idx = get_adjacent_computer(next_pos, dir);
                if (adj_comp_idx == -1) continue;
                if (comp.type == computers[adj_comp_idx].type)
                    score += get_cluster(adj_comp_idx) - 1;
            }

            // x -- o -- x to x ----- x
            for (auto [d1, d2] : std::vector<std::pair<Pos, Pos>>{{left, right}, {up, down}}) {
                int d1_comp_idx = get_adjacent_computer(next_pos, d1);
                int d2_comp_idx = get_adjacent_computer(next_pos, d2);

                if (d1_comp_idx != -1 and d2_comp_idx != -1 and computers[d1_comp_idx].type == computers[d2_comp_idx].type) {
                    int d1_cluster_size = get_cluster(d1_comp_idx, d2_comp_idx);
                    int d2_cluster_size = get_cluster(d2_comp_idx, d1_comp_idx);
                    std::cerr << "connected!" << std::endl;
                    std::cerr << d1_cluster_size << " " << d2_cluster_size << std::endl;
                    bool not_in_same_cluster = d1_cluster_size != -1 and d2_cluster_size != -1;
                    if (not_in_same_cluster) {
                        score += d1_cluster_size * d2_cluster_size;
                    }
                }
            }

            std::cerr << comp.pos << " " << next_pos << ", Score: " << score << std::endl;
            if (score > best_score) {
                best_score = score;
                best_pos = next_pos;
            }
        }

        if (best_score > 0) {
            moves.push_back({comp.pos, best_pos});
            computers[comp_idx].pos = best_pos;
            std::swap(field[comp.pos.y][comp.pos.x], field[best_pos.y][best_pos.x]);

            std::cerr << best_score << " " << comp.pos << " " << best_pos << std::endl;

            // output();
        }
        std::cerr << sum << std::endl;
    };

    // while (elapsed_seconds() < 2.8) {
    // while (moves.size() < k * 35 && elapsed_seconds() < 2.8) {
    for (int i = 0; i < 10; i++) {
        search_move();
    }

    output();
}