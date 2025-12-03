# Content Conversion Guide

This guide helps you convert Word document content to Markdown format for the help page.

## Quick Conversion Steps

1. **Extract Images from Word Document**
   - Open the Word document
   - Right-click each image → "Save as Picture"
   - Save to `public/help/docs/images/` with descriptive names
   - Recommended formats: PNG for screenshots, JPG for photos

2. **Convert Text Content**
   - Copy text from Word document
   - Convert formatting:
     - **Bold text** → `**Bold text**`
     - *Italic text* → `*Italic text*`
     - Headers → `# Header 1`, `## Header 2`, `### Header 3`
     - Bullet lists → Use `-` or `*`
     - Numbered lists → Use `1.`, `2.`, etc.

3. **Add Image References**
   - For each image, add: `![Image Description](./images/filename.png)`
   - Place images near relevant text

4. **Update help.md**
   - Replace content in `public/help/docs/help.md`
   - Test locally before deploying

## Markdown Formatting Reference

### Headers
```markdown
# Header 1
## Header 2
### Header 3
#### Header 4
```

### Text Formatting
```markdown
**Bold text**
*Italic text*
***Bold and italic***
```

### Lists
```markdown
- Unordered item 1
- Unordered item 2

1. Ordered item 1
2. Ordered item 2
```

### Images
```markdown
![Alt text describing the image](/help/docs/images/image-name.png)
```

**Important**: Use absolute paths starting with `/help/docs/images/` for images to ensure they load correctly from the help page.

### Links
```markdown
[Link text](https://example.com)
```

### Code Blocks
````markdown
```bash
# Code example
echo "Hello World"
```
````

### Tables
```markdown
| Column 1 | Column 2 |
|----------|----------|
| Row 1    | Data     |
| Row 2    | Data     |
```

## Image Best Practices

1. **Naming**: Use descriptive, lowercase names with hyphens
   - ✅ `dashboard-overview.png`
   - ❌ `IMG_1234.PNG`

2. **Sizing**: Optimize images (max 1200px width recommended)
3. **Format**: PNG for screenshots, JPG for photos
4. **Alt Text**: Always include descriptive alt text for accessibility

## Testing

After updating `help.md`:
1. Rebuild frontend: `npm run build`
2. Test locally: `npm run preview` or deploy to server
3. Verify images load correctly
4. Check formatting renders properly

## Example Conversion

**Word Document:**
```
StackWatch Documentation

This is a screenshot:
[Image: dashboard.png]

Features:
• Feature 1
• Feature 2
```

**Markdown Equivalent:**
```markdown
# StackWatch Documentation

This is a screenshot:

![Dashboard Overview](/help/docs/images/dashboard.png)

Features:
- Feature 1
- Feature 2
```

