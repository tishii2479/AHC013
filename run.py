import argparse
import subprocess
import sys


def test_run(exe_file: str, n: int, run: int) -> None:
    total_sum = 0
    score_max = 10000
    hist_div = 20
    hist_w = score_max // hist_div
    hist = [0] * hist_div
    scores = []

    for i in range(n):
        print(exe_file + ": " + str(i), file=sys.stderr)
        sum = 0
        in_file = "in/" + str(i).zfill(4) + ".txt"
        out_file = "out/" + str(i).zfill(4) + ".txt"
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

        print("Average score for", in_file, sum / run)
        print("Average is", total_sum / (i + 1) / run)
    print("[RESULT] Average is", total_sum / n / run, ":", exe_file)

    print("Score distribution:")

    for i in range(hist_div):
        print(
            str(i * hist_w).zfill(4)
            + " ~ "
            + str((i + 1) * hist_w - 1).zfill(4)
            + ": "
            + "o" * (hist[i] * 100 // n)
        )

    print("Worst cases:")
    scores.sort()

    for i in range(10):
        print(f"Case: {scores[i][1]}, score: {scores[i][0]}")

    print("Best cases:")
    for i in range(10):
        print(f"Case: {scores[-i-1][1]}, score: {scores[-i-1][0]}")


parser = argparse.ArgumentParser()
parser.add_argument("--n", type=int, default=100)
parser.add_argument("--run", type=int, default=1)
parser.add_argument("--exe", type=str, default="./main.o")

args = parser.parse_args()

print(args)

test_run(exe_file=args.exe, n=args.n, run=args.run)
