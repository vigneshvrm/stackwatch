# Help Documentation Images

This directory contains images used in the StackWatch help documentation.

## Image Guidelines

### Supported Formats
- PNG (recommended for screenshots and diagrams)
- JPG/JPEG (for photos)
- GIF (for animated images)
- SVG (for vector graphics)

### Naming Convention
Use descriptive, lowercase filenames with hyphens:
- ✅ `dashboard-overview.png`
- ✅ `prometheus-query-example.png`
- ✅ `grafana-dashboard-setup.jpg`
- ❌ `image1.png`
- ❌ `IMG_1234.JPG`

### Image Optimization
- Compress images before adding (use tools like TinyPNG, ImageOptim)
- Recommended max width: 1200px for screenshots
- Keep file sizes reasonable (< 500KB per image when possible)

## Usage in Markdown

Reference images in your Markdown files using absolute paths:

```markdown
![Image Description](/help/docs/images/filename.png)
```

**Important**: Always use absolute paths starting with `/help/docs/images/` to ensure images load correctly from the help page.

## Image Path Resolution

Images will be served from:
- URL: `http://server-ip/help/docs/images/filename.png`
- Local path: `public/help/docs/images/filename.png`

## Adding Images

1. Place image files in this directory
2. Reference them in `help.md` using the format above
3. Rebuild frontend: `npm run build`
4. Redeploy: `sudo ./scripts/deploy-nginx.sh`

