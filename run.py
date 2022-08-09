import subprocess
import sys


def test_run(exe_file: str) -> None:
    n = 100
    run = 1
    total_sum = 0
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
            exec = "./tester.o < tmp"
            proc = subprocess.run(
                f"cat {in_file} {out_file} > tmp && " + exec + " && rm tmp",
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
            sum += int(score)
            total_sum += int(score)
        print("Average score for", in_file, sum / run)
        print("Average is", total_sum / (i + 1) / run)
    print("[RESULT] Average is", total_sum / n / run, ":", exe_file)


test_run("./main.o")
