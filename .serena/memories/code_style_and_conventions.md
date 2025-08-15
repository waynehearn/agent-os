# Code Style and Conventions

## JavaScript Conventions
- **Module Pattern**: Use IIFE (Immediately Invoked Function Expression) for encapsulation
- **Function Names**: Clear, descriptive names (e.g., `renderKiboAgentBadge`, `mountBadge`)
- **SVG Creation**: Use helper functions for element creation (`el()`, `text()`)
- **DOM Ready**: Check document.readyState and handle both loading and ready states
- **Accessibility**: Include aria attributes, title/desc elements for SVG, screen-reader-only text

## CSS Conventions  
- **Namespace**: Use `kibo-` prefix for all classes (e.g., `.kibo-badge`, `.kibo-container`)
- **CSS Variables**: Define color palette in `:root` with semantic names
- **Layout**: Use CSS Grid/Flexbox, avoid floats
- **Typography**: System font stack for cross-platform consistency

## HTML Conventions
- **Semantic HTML**: Use proper heading hierarchy, main/section elements
- **Accessibility**: Include aria-live, proper labeling, screen reader support
- **DOM Hooks**: Use semantic IDs for JavaScript targeting (`#kibo-agent-badge-container`)

## File Organization
- **Single Responsibility**: Each file has clear purpose (app.js for badge logic, styles.css for styling)
- **Inline SVG**: Prefer inline SVG over external files for small graphics
- **No Dependencies**: Keep everything framework-free and portable

## Naming Patterns
- Files: kebab-case (app.js, styles.css)
- Classes: kebab-case with namespace (.kibo-badge-wrap)
- Functions: camelCase (renderKiboAgentBadge)
- Variables: camelCase (const width = 280)