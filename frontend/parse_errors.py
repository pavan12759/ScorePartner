import re

def main():
    try:
        with open('analyze.log', 'r', encoding='utf-16') as f:
            lines = f.readlines()
            
        errors = [line for line in lines if 'error -' in line]
        
        files = set()
        for line in errors:
            match = re.search(r'error - ([a-zA-Z0-9_\\]+\.dart):', line)
            if match:
                files.add(match.group(1))
            else:
                match2 = re.search(r'error - (.*?\.dart):', line)
                if match2:
                    files.add(match2.group(1))
                    
        print(f'Total error lines: {len(errors)}')
        print(f'Files with errors: {len(files)}')
        for f in files:
            print(f)
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    main()
