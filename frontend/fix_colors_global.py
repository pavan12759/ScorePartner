import re
import os

directories = [
    r"d:\ScorePartner\frontend\lib\presentation\screens\main",
    r"d:\ScorePartner\frontend\lib\presentation\screens\search",
    r"d:\ScorePartner\frontend\lib\presentation\screens\tournament",
    r"d:\ScorePartner\frontend\lib\presentation\screens\profile",
    r"d:\ScorePartner\frontend\lib\presentation\screens\teams",
]

for d in directories:
    for root, dirs, files in os.walk(d):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                with open(file_path, "r", encoding="utf-8") as f:
                    original_content = f.read()
                
                content = original_content

                # Backgrounds
                content = re.sub(r'backgroundColor:\s*Colors\.white,?', r'backgroundColor: ThemeHelper.of(context).scaffoldBg,', content)
                content = re.sub(r'backgroundColor:\s*Colors\.grey\[50\],?', r'backgroundColor: ThemeHelper.of(context).scaffoldBg,', content)
                
                # Card colors
                content = re.sub(r'color:\s*Colors\.white,?', r'color: ThemeHelper.of(context).cardBg,', content)
                content = re.sub(r'color:\s*Colors\.white\)', r'color: ThemeHelper.of(context).cardBg)', content)
                
                # Text Colors
                content = re.sub(r'Colors\.black87', r'ThemeHelper.of(context).textPrimary', content)
                content = re.sub(r'Colors\.black54', r'ThemeHelper.of(context).textSecondary', content)
                content = re.sub(r'Colors\.black38', r'ThemeHelper.of(context).textSecondary', content)
                
                # We should be careful about replacing Colors.black when it is followed by .withOpacity
                content = re.sub(r'color:\s*Colors\.black,', r'color: ThemeHelper.of(context).textPrimary,', content)
                content = re.sub(r'color:\s*Colors\.black\)', r'color: ThemeHelper.of(context).textPrimary)', content)
                content = re.sub(r'color:\s*Colors\.black\n', r'color: ThemeHelper.of(context).textPrimary\n', content)
                
                # Grey shade texts/borders
                content = re.sub(r'Colors\.grey\.shade[456789]00', r'ThemeHelper.of(context).textSecondary', content)
                content = re.sub(r'Colors\.grey\[[456789]00\]', r'ThemeHelper.of(context).textSecondary', content)
                content = re.sub(r'Colors\.grey\.shade[123]00', r'ThemeHelper.of(context).dividerColor!', content)
                content = re.sub(r'Colors\.grey\[[123]00\]', r'ThemeHelper.of(context).dividerColor!', content)
                content = re.sub(r'Colors\.grey\.shade50', r'ThemeHelper.of(context).dividerColor!', content)
                content = re.sub(r'color:\s*Colors\.grey(?=[,\)])', r'color: ThemeHelper.of(context).textSecondary', content)

                # Shadows
                content = re.sub(r'color:\s*Colors\.black\.withOpacity\((0\.0[456])\)', 
                                 r'color: ThemeHelper.of(context).isDark ? Colors.transparent : Colors.black.withOpacity(\1)', content)

                if content != original_content:
                    if 'package:scorepatner/core/theme/app_theme.dart' not in content:
                        content = re.sub(r'(import [^\n]+;)', r"\1\nimport 'package:scorepatner/core/theme/app_theme.dart';", content, count=1)
                    
                    lines = content.split('\n')
                    for i in range(len(lines)):
                        if 'ThemeHelper.of(context)' in lines[i]:
                            lines[i] = re.sub(r'\bconst\s+', '', lines[i])
                            if i > 0 and lines[i-1].strip().startswith('const '):
                                lines[i-1] = re.sub(r'\bconst\s+', '', lines[i-1])
                    content = '\n'.join(lines)
                    
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(content)
                    print(f"Updated {file_path}")
