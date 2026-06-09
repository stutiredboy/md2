## MODIFIED Requirements

### Requirement: Offline rendering with graceful error handling
The system SHALL render diagrams without any runtime network access, using engine assets bundled with the application. While an engine has not yet rendered a block, the system SHALL NOT display the block's raw source as visible text; the source SHALL remain available to the engine. When diagram source cannot be parsed by its engine, or no engine is available, the system SHALL surface the offending source or an inline error and SHALL continue to render the rest of the document.

#### Scenario: Diagram renders without network
- **WHEN** the preview is shown for a document containing a `mermaid` block while the machine is offline
- **THEN** the diagram is fully rendered using bundled assets

#### Scenario: Raw source is not shown while waiting to render
- **WHEN** a document with a diagram block is previewed before its engine finishes rendering
- **THEN** the raw diagram source is not displayed as visible code to the reader
- **AND** the rendered diagram is shown once the engine completes

#### Scenario: Invalid diagram source does not break the page
- **WHEN** a `mermaid` block contains malformed source such as `graph TD; A-->`
- **THEN** the rest of the document still renders normally
- **AND** the problematic block is shown as an error or its raw source instead of blanking the preview
