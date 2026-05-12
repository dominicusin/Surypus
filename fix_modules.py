#!/usr/bin/env python3
import os
import re

src_dir = "/home/domini/src/My/Surypus/src"

def fix_module_syntax(content):
    # Pattern 1: module X where ( ... ) -> module X ( ... ) where
    pattern1 = r'module\s+(\S+)\s+where\s*\n\s*\((.*?)\)\s*\nwhere'
    replacement1 = r'module \1\n  (\2) where'
    content = re.sub(pattern1, replacement1, content, flags=re.DOTALL)
    
    # Pattern 2: Fix ( Type (..) ) -> ( Type(..) )
    content = re.sub(r'\(\s*\.\.\s*\)', '(..)', content)
    
    # Pattern 3: Fix trailing commas in export lists
    content = re.sub(r',\s*\)', '\n  )', content)
    
    return content

for root, dirs, files in os.walk(src_dir):
    for file in files:
        if file.endswith('.hs'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            new_content = fix_module_syntax(content)
            
            if content != new_content:
                with open(filepath, 'w') as f:
                    f.write(new_content)
                print(f"Fixed: {filepath}")

print("Done!")
