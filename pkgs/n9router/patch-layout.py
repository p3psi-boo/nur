import re
import sys

with open('src/app/layout.js', 'r') as f:
    content = f.read()

# Remove the Google Font import line
content = re.sub(r'import \{ Inter \} from "next/font/google";\n', '', content)

# Replace the Inter() call block with a plain object
content = re.sub(
    r'const inter = Inter\(\{\s*subsets: \["latin"\],\s*variable: "--font-inter",\s*\}\);',
    'const inter = { className: "", variable: "--font-inter" };',
    content
)

with open('src/app/layout.js', 'w') as f:
    f.write(content)
