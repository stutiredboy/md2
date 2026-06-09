## ADDED Requirements

### Requirement: Mermaid diagram rendering
The system SHALL detect fenced code blocks whose info string is `mermaid` and SHALL render their content as a Mermaid diagram in the Read-mode preview. The diagram source SHALL be passed to the Mermaid engine verbatim and SHALL NOT be processed by inline Markdown rules or syntax highlighting.

#### Scenario: Mermaid flowchart is rendered
- **WHEN** the source contains a fenced block opening with ` ```mermaid ` followed by `graph TD; A-->B;` and a closing fence
- **THEN** the preview renders a graphical flowchart with nodes `A` and `B` connected by an arrow
- **AND** the literal text `graph TD; A-->B;` is not shown as plain code

#### Scenario: Mermaid sequence diagram is rendered
- **WHEN** a `mermaid` fenced block contains `sequenceDiagram` with `Alice->>Bob: Hello`
- **THEN** the preview renders a graphical sequence diagram with participants `Alice` and `Bob`

### Requirement: flowchart.js diagram rendering
The system SHALL detect fenced code blocks whose info string is `flow` and SHALL render their content as a diagram using the flowchart.js engine in the Read-mode preview. The diagram source SHALL be passed to the engine verbatim.

#### Scenario: flowchart.js block is rendered
- **WHEN** the source contains a fenced block opening with ` ```flow ` whose body defines `st=>start: Start` and `e=>end: End` with a connection `st->e`
- **THEN** the preview renders a graphical flowchart for the defined nodes
- **AND** the literal flowchart.js DSL text is not shown as plain code

### Requirement: Sequence diagram rendering
The system SHALL detect fenced code blocks whose info string is `sequence` and SHALL render their content as a sequence diagram using the js-sequence-diagrams engine in the Read-mode preview. The diagram source SHALL be passed to the engine verbatim.

#### Scenario: sequence block is rendered
- **WHEN** the source contains a fenced block opening with ` ```sequence ` whose body is `Alice->Bob: Hi` and `Bob-->Alice: Hello`
- **THEN** the preview renders a graphical sequence diagram with the two messages
- **AND** the literal sequence DSL text is not shown as plain code

### Requirement: Diagram blocks do not interfere with ordinary code
The system SHALL render only the `mermaid`, `flow`, and `sequence` info strings as diagrams. Fenced code blocks with any other info string (or none) SHALL continue to render as syntax-highlighted or plain code exactly as before this change.

#### Scenario: Unknown language stays a code block
- **WHEN** a fenced block opens with ` ```swift ` containing `let a = 1`
- **THEN** the preview renders a normal syntax-highlighted code block
- **AND** no diagram rendering is attempted

#### Scenario: Diagram source inside an unrelated code block stays literal
- **WHEN** a fenced block opens with ` ```text ` whose body contains `graph TD; A-->B;`
- **THEN** the preview shows the literal text as a code block
- **AND** no diagram is rendered

### Requirement: Offline rendering with graceful error handling
The system SHALL render diagrams without any runtime network access, using engine assets bundled with the application. When diagram source cannot be parsed by its engine, the system SHALL surface the offending source or an inline error and SHALL continue to render the rest of the document.

#### Scenario: Diagram renders without network
- **WHEN** the preview is shown for a document containing a `mermaid` block while the machine is offline
- **THEN** the diagram is fully rendered using bundled assets

#### Scenario: Invalid diagram source does not break the page
- **WHEN** a `mermaid` block contains malformed source such as `graph TD; A-->`
- **THEN** the rest of the document still renders normally
- **AND** the problematic block is shown as an error or its raw source instead of blanking the preview

### Requirement: Diagram legibility in light and dark mode
Rendered diagrams SHALL be legible in both light and dark color schemes, with text and lines that contrast against the preview background.

#### Scenario: Diagram is readable in dark mode
- **WHEN** the system appearance is dark and a document with a diagram is previewed
- **THEN** the diagram's text and connectors are clearly readable against the dark background
