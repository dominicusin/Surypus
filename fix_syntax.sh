#!/bin/bash
# Fix syntax errors in Haskell files

# Fix (..) patterns in module exports
find /home/domini/src/My/Surypus/src -name "*.hs" -exec sed -i 's/(\.\.\)/(..)/g' {} \;

# Fix module export syntax
echo "Syntax fixes applied!"
