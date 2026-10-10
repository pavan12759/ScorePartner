import re
import os

def fix_errors():
    try:
        with open('analyze.log', 'r', encoding='utf-16') as f:
            lines = f.readlines()
    except Exception as e:
        print("Could not read analyze.log", e)
        return

    errors = [line for line in lines if 'error -' in line]
    
    # Group errors by file
    from collections import defaultdict
    file_errors = defaultdict(list)
    
    for line in errors:
        match = re.search(r'error - (.*?\.dart):(\d+):(\d+) - (.*) - (.*)', line)
        if match:
            filepath = match.group(1).strip()
            filepath = 'lib/' + filepath.replace('\\', '/')
            lineno = int(match.group(2))
            colno = int(match.group(3))
            msg = match.group(4)
            rule = match.group(5).strip()
            
            # Map to absolute path
            abs_path = os.path.abspath(filepath)
            file_errors[abs_path].append({
                'line': lineno,
                'col': colno,
                'msg': msg,
                'rule': rule
            })

    for filepath, errs in file_errors.items():
        if not os.path.exists(filepath):
            print(f"File not found: {filepath}")
            continue
            
        with open(filepath, 'r', encoding='utf-8') as f:
            content_lines = f.readlines()
            
        modified = False
        
        for err in errs:
            lineno = err['line'] - 1 # 0-indexed
            rule = err['rule']
            
            if 0 <= lineno < len(content_lines):
                line_content = content_lines[lineno]
                
                # Fix const_with_non_const
                if rule == 'const_with_non_const' or "isn't a const constructor" in err['msg'] or "Cannot invoke a non-'const'" in err['msg']:
                    # Remove 'const ' from the line
                    new_line = re.sub(r'\bconst\s+', '', line_content)
                    if new_line != line_content:
                        content_lines[lineno] = new_line
                        modified = True
                    else:
                        # Sometimes the const is on the previous line
                        if lineno > 0 and 'const ' in content_lines[lineno - 1]:
                            content_lines[lineno - 1] = re.sub(r'\bconst\s+', '', content_lines[lineno - 1])
                            modified = True
                            
                # Fix undefined_identifier for context
                elif rule == 'undefined_identifier' and "'context'" in err['msg']:
                    # We need to change Theme.of(context) to AppTheme.darkTheme
                    # or better: we just remove Theme.of(context) and use colors directly
                    # Wait, we replaced with ThemeHelper.of(context).cardBg
                    # If context is not available, we can just replace it back to Colors.white
                    if 'ThemeHelper.of(context)' in line_content:
                        new_line = line_content.replace('ThemeHelper.of(context).cardBg', 'Colors.white')
                        new_line = new_line.replace('ThemeHelper.of(context).scaffoldBg', 'Colors.grey[50]')
                        new_line = new_line.replace('ThemeHelper.of(context).textPrimary', 'Colors.black')
                        new_line = new_line.replace('ThemeHelper.of(context).textSecondary', 'Colors.grey[600]')
                        new_line = new_line.replace('ThemeHelper.of(context).dividerColor!', 'Colors.grey[200]')
                        if new_line != line_content:
                            content_lines[lineno] = new_line
                            modified = True
                
                elif rule == 'dot_shorthand_undefined_member' or rule == 'extra_positional_arguments_could_be_named':
                    # Fix stray comma before .withOpacity
                    if ',.withOpacity' in line_content:
                        new_line = line_content.replace(',.withOpacity', '.withOpacity')
                        content_lines[lineno] = new_line
                        modified = True
                    elif 'ThemeHelper.of(context).textPrimary,.withOpacity' in line_content:
                        new_line = line_content.replace('ThemeHelper.of(context).textPrimary,.withOpacity', 'ThemeHelper.of(context).textPrimary.withOpacity')
                        content_lines[lineno] = new_line
                        modified = True
                    elif ',.withValues' in line_content:
                        new_line = line_content.replace(',.withValues', '.withValues')
                        content_lines[lineno] = new_line
                        modified = True

        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(content_lines)
            print(f"Fixed errors in {filepath}")

if __name__ == '__main__':
    fix_errors()
