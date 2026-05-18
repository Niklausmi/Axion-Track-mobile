import os
import re

def find_containers():
    lib_dir = 'c:/axion_track_flutter/axion_track/lib'
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'):
                continue
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find all 'Container('
            idx = 0
            while True:
                idx = content.find('Container(', idx)
                if idx == -1: break
                
                # find the matching closing parenthesis
                start = idx + 9 # at '('
                paren_count = 0
                for i in range(start, len(content)):
                    if content[i] == '(': paren_count += 1
                    elif content[i] == ')':
                        paren_count -= 1
                        if paren_count == 0:
                            end = i
                            break
                else:
                    break
                
                container_args = content[start+1:end]
                
                # Now we need to parse top-level arguments
                # An argument is top-level if it's not inside () [] or {}
                # Let's extract top-level keys
                top_level_keys = set()
                arg_start = 0
                nest = 0
                for i in range(len(container_args)):
                    if container_args[i] in '([{': nest += 1
                    elif container_args[i] in ')]}': nest -= 1
                    elif container_args[i] == ':' and nest == 0:
                        # found a key
                        # The key is from the previous comma or start to this colon
                        prev_comma = container_args.rfind(',', arg_start, i)
                        key_start = prev_comma + 1 if prev_comma != -1 else arg_start
                        key = container_args[key_start:i].strip()
                        top_level_keys.add(key)
                        arg_start = i + 1
                
                if 'color' in top_level_keys and 'decoration' in top_level_keys:
                    print(f"Found in {path}:")
                    # print line number
                    line_no = content[:idx].count('\n') + 1
                    print(f"Line {line_no}: {content[idx:idx+100]}...")
                
                idx = end + 1

if __name__ == '__main__':
    find_containers()
