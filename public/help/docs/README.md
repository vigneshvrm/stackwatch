# Help Documentation

This directory contains Markdown documentation files that are displayed in the Help & Documentation page.

## Adding Documentation

1. **Create or edit Markdown files** in this directory (`public/help/docs/`)
2. **Use standard Markdown syntax** - the page supports:
   - Headers (# ## ###)
   - Lists (ordered and unordered)
   - Links
   - Code blocks
   - Tables (via GitHub Flavored Markdown)
   - Bold and italic text

3. **Update the main help file**: Edit `help.md` to include links to other documentation files if needed

4. **Rebuild the frontend**: After adding/editing files, rebuild the frontend:
   ```bash
   npm run build
   ```

5. **Redeploy**: Run the Nginx deployment script to copy the new build:
   ```bash
   sudo ./scripts/deploy-nginx.sh
   ```

## File Structure

- `help.md` - Main help documentation file (loaded by default)
- `README.md` - This file
- Add additional `.md` files as needed

## Accessing Documentation

- **Via UI**: Click the "Help & Documentation" button on the dashboard
- **Direct URL**: `http://your-server-ip/help`
- **Markdown files**: `http://your-server-ip/help/docs/help.md`

## Markdown Features Supported

The Help page uses `react-markdown` with GitHub Flavored Markdown (GFM) support:

- ✅ Headers
- ✅ Paragraphs and line breaks
- ✅ **Bold** and *italic* text
- ✅ Lists (ordered and unordered)
- ✅ Links
- ✅ Code blocks (with syntax highlighting)
- ✅ Inline code
- ✅ Tables
- ✅ Blockquotes
- ✅ Horizontal rules

## Example Markdown

```markdown
# Title

## Section

- List item 1
- List item 2

**Bold text** and *italic text*

[Link text](https://example.com)

\`\`\`bash
# Code block
echo "Hello World"
\`\`\`
```

