# Suggested Commands

## Development Workflow

### View the Demo
```bash
# Open demo in browser (Windows)
start site/index.html
```

### File Management
```bash
# List all files
ls -la

# Check project structure
find . -type f -name "*.html" -o -name "*.js" -o -name "*.css"

# View git status
git status
```

### Code Exploration
```bash
# Search for specific functions
grep -r "function\|const.*=" site/

# Find CSS classes
grep -r "kibo-" site/

# Check for SVG elements
grep -r "svg\|SVG" site/
```

## Task Completion Checklist
Since this is a static demo with no build process, after making changes:

1. **Save files** - ensure all edits are saved
2. **Refresh browser** - reload site/index.html to see changes  
3. **Visual check** - verify badge renders correctly
4. **Accessibility check** - ensure screen reader labels work
5. **Git commit** - if changes should be committed

## No Build/Test Commands Required
- No package.json or npm scripts
- No linting tools configured  
- No test framework setup
- No bundling or compilation needed

## Quick Validation
```bash
# Check that badge container exists in HTML
grep "kibo-agent-badge-container" site/index.html

# Verify JavaScript is linked
grep "app.js" site/index.html

# Check CSS is linked  
grep "styles.css" site/index.html
```