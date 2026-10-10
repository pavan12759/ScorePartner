import re
import os

# All directories that were modified by the previous script
directories = [
    r"d:\ScorePartner\frontend\lib\presentation\screens\main",
    r"d:\ScorePartner\frontend\lib\presentation\screens\search",
    r"d:\ScorePartner\frontend\lib\presentation\screens\tournament",
    r"d:\ScorePartner\frontend\lib\presentation\screens\profile",
    r"d:\ScorePartner\frontend\lib\presentation\screens\teams",
    r"d:\ScorePartner\frontend\lib\presentation\screens\matches",
]

fixed_files = []

for d in directories:
    for root, dirs, files in os.walk(d):
        for file in files:
            if not file.endswith(".dart"):
                continue
            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8") as f:
                original = f.read()

            content = original

            # ── Pattern 1: ThemeHelper.of(context).cardBg,XX  (from Colors.whiteXX) ──
            # These were Colors.white60, Colors.white70 etc. They should become
            # ThemeHelper.of(context).textSecondary  (semi-transparent text on colored bg)
            content = re.sub(
                r'ThemeHelper\.of\(context\)\.cardBg,\s*\d+',
                'ThemeHelper.of(context).textSecondary',
                content
            )

            # ── Pattern 2: ThemeHelper.of(context).textPrimary,XX  (from Colors.blackXX) ──
            # e.g. Colors.black12 → ThemeHelper.of(context).textPrimary,12
            # These are very light opacity blacks used for shadows/borders
            content = re.sub(
                r'ThemeHelper\.of\(context\)\.textPrimary,\s*(\d+)',
                lambda m: 'Colors.black.withOpacity(0.%s)' % m.group(1) if int(m.group(1)) < 50 else 'ThemeHelper.of(context).textSecondary',
                content
            )

            # ── Pattern 3: Stray comma before .withOpacity / .withValues ──
            # ThemeHelper.of(context).textPrimary,.withOpacity(...)
            content = re.sub(
                r'(ThemeHelper\.of\(context\)\.\w+),\.with(Opacity|Values)',
                r'\1.with\2',
                content
            )

            # ── Pattern 4: Also fix cardBg,.withOpacity ──
            content = re.sub(
                r'(ThemeHelper\.of\(context\)\.cardBg),\.with(Opacity|Values)',
                r'\1.with\2',
                content
            )

            # ── Pattern 5: Remove const from lines containing ThemeHelper ──
            lines = content.split('\n')
            i = 0
            while i < len(lines):
                line = lines[i]
                if 'ThemeHelper.of(context)' in line and 'const ' in line:
                    lines[i] = line.replace('const ', '', 1)
                # Also check if the NEXT line has ThemeHelper and current line
                # ends with const (like "const BoxShadow(\n  color: ThemeHelper...")
                if i + 1 < len(lines) and 'ThemeHelper.of(context)' in lines[i + 1]:
                    if 'const ' in line:
                        lines[i] = line.replace('const ', '', 1)
                # Check up to 5 lines ahead for ThemeHelper inside a const block
                if 'const ' in line:
                    for j in range(i + 1, min(i + 8, len(lines))):
                        if 'ThemeHelper.of(context)' in lines[j]:
                            lines[i] = line.replace('const ', '', 1)
                            break
                        # Stop looking if we hit a closing bracket at same or lesser indent
                        stripped = lines[j].strip()
                        if stripped.startswith(')') or stripped.startswith(']'):
                            break
                i += 1
            content = '\n'.join(lines)

            # ── Pattern 6: Fix double !! (dividerColor!!) ──
            content = content.replace('dividerColor!!', 'dividerColor!')

            if content != original:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(content)
                fixed_files.append(file_path)

print(f"Fixed {len(fixed_files)} files:")
for f in fixed_files:
    print(f"  {f}")
