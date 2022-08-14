import argparse
import subprocess
import sys
from typing import List, Tuple


def test_run(
    exe_file: str, cases: int, run: int, verbose: bool = True
) -> List[Tuple[Tuple[int, int], float]]:
    total_sum = 0
    score_max = 10000
    hist_div = 20
    hist_w = score_max // hist_div
    hist = [0] * hist_div
    scores = []
    max_score_sum = 0
    results: List[Tuple[Tuple[int, int], float]] = []

    for i in range(cases):
        print(exe_file + ": " + str(i), file=sys.stderr)
        sum = 0
        in_file = "in/" + str(i).zfill(4) + ".txt"
        out_file = "out/" + str(i).zfill(4) + ".txt"
        max_score = 0

        with open(in_file, "r") as f:
            n, k = map(int, f.readline().split())

        for _ in range(run):
            _ = subprocess.run(
                f"{exe_file} < {in_file} > {out_file}",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            proc = subprocess.run(
                f"cat {in_file} {out_file} | ./tester.o",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            stdout = proc.stdout.decode("utf8")

            # parse Score = %d
            score = ""
            ok = False
            for c in stdout:
                if c == "=":
                    ok = True
                if c.isdigit() and ok:
                    score += c
            score = int(score)
            sum += score
            total_sum += score
            hist[score // hist_w] += 1
            scores.append((score, i))

            max_score = max(max_score, score)

        max_score_sum += max_score
        if verbose or i % (cases // 10) == 0:
            print("Average score for", in_file, sum / run)
            print("    Max score for", in_file, max_score)
            print("          Average for", total_sum / (i + 1) / run)
            print("Max score average for", in_file, max_score_sum / (i + 1))
            results.append(((n, k), sum / run))
    print("[RESULT] Average is", total_sum / cases / run, ":", exe_file)
    print("[RESULT] Max score average is", max_score_sum / cases, ":", exe_file)

    print("Score distribution:")

    for i in range(hist_div):
        print(
            str(i * hist_w).zfill(4)
            + " ~ "
            + str((i + 1) * hist_w - 1).zfill(4)
            + ": "
            + "o" * (hist[i] * 100 // cases // run)
        )

    print("Worst cases:")
    scores.sort()

    for i in range(10):
        print(f"Case: {scores[i][1]}, score: {scores[i][0]}")

    print("Best cases:")
    for i in range(10):
        print(f"Case: {scores[-i-1][1]}, score: {scores[-i-1][0]}")

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=100)
    parser.add_argument("--run", type=int, default=1)
    parser.add_argument("--exe", type=str, default="./main.o")

    args = parser.parse_args()

    print(args)

    test_run(exe_file=args.exe, cases=args.n, run=args.run)
