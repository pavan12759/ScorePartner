
file_path = r"d:\ScorePatner\ScorePartner\lib\presentation\screens\tournament\tournament_details_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i, line in enumerate(lines):
    # comments
    line = line.split('//')[0] 
    for char in line:
        if char == '{':
            balance += 1
        elif char == '}':
            balance -= 1
            if balance == 0:
                print(f"Balance hit 0 at line {i+1}")
