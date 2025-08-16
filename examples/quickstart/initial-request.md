<!-- markdownlint-disable MD041 MD032 MD007 MD034 -->

@~/.agent-os/instructions/core/create-spec.md

[spec_inputs]
main_idea: >
  Add a playful Spec Agent K badge widget to the simple HTML/JS demo page. The badge renders a cute “spy-bot” SVG that humorously nods to a special agent theme and Kibo.

initial_user_stories:
  - title: Show Spec Agent K badge
    story: As a visitor, I want to see a fun Spec Agent K “agent” badge so that I immediately know what the project is about.
    details: >
      The badge is generated as inline SVG on page load into a container with id "kibo-agent-badge-container". It includes accessible text and a link to the Kibo docs.

in_scope:
  - Frontend: Implement a small JS module in `site/app.js` that renders the inline SVG badge
  - Frontend: Add minimal CSS styles in `site/styles.css` for a polished “agent” look
  - Frontend: Ensure accessible labeling (title/desc and a visually hidden label)
  - Content: Add a clear link to Spec Agent K docs

out_of_scope:
  - Backend services or build tooling
  - External image hosting or libraries

expected_deliverables:
  - A visible “Spec Agent K” badge renders on `site/index.html` inside `#kibo-agent-badge-container`
  - Badge includes accessible title/description and a link to <https://buildermethods.com/agent-os>
  - Code is plain HTML/CSS/JS with no bundler; loads by opening the file

tech_constraints: >
  HTML5 + CSS3 + Vanilla JavaScript (ES2020+). No frameworks, no bundlers. Keep the SVG small and self-contained.

requires_db_changes: false
requires_api_changes: false

spec_name_override: "add-kibo-agent-badge-widget"
overwrite_existing: true
[/spec_inputs]
