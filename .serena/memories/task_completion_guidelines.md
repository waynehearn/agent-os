# Task Completion Guidelines

## What to Do When Tasks Are Completed

### 1. Immediate Validation
- **Save all files** - ensure all code changes are persisted
- **Visual verification** - open `site/index.html` in browser to verify changes
- **Functionality check** - ensure the Kibo Agent Badge renders correctly
- **Accessibility validation** - check that screen reader labels work properly

### 2. Code Quality Check
Since there are no automated tools, manually verify:
- **JavaScript**: No syntax errors, functions work as expected
- **CSS**: Styles apply correctly, no broken layouts
- **HTML**: Valid structure, proper accessibility attributes
- **SVG**: Badge renders with correct styling and dimensions

### 3. Integration Testing
- **DOM integration**: Badge mounts correctly in the container
- **Cross-browser**: Test in multiple browsers if possible
- **Responsive**: Ensure badge displays well on different screen sizes
- **Performance**: SVG should load quickly without layout shifts

### 4. Documentation
- **No automatic docs** - this is a simple demo with no documentation generation
- **Comments**: Ensure code has helpful inline comments where needed
- **README**: Update README.md only if significant functionality is added

### 5. Version Control
```bash
# Check what changed
git status
git diff

# Commit if appropriate (only when explicitly requested)
git add .
git commit -m "Descriptive message about changes"
```

## No Automated Tooling
This project intentionally has:
- **No linting** - manual code review
- **No testing framework** - manual browser testing
- **No build process** - direct file editing
- **No formatting tools** - maintain consistent style manually

## Success Criteria
A task is complete when:
1. Code changes achieve the specified requirements
2. Badge renders correctly in the browser
3. No console errors or visual issues
4. Accessibility features work properly
5. Code follows established patterns and conventions