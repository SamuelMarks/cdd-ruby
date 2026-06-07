# Model Context Protocol (MCP) CLI Conformance Table

This table tracks the completeness of language CLI integration with the Model Context Protocol (MCP). It is divided into three sections:
1. **Architectural Integration Layers**: Tracks the exposure of MCP across the CLI, SDK, and Server boundaries.
2. **Semantic & Conceptual Features**: Tracks protocol mechanics, transports, and behavioral requirements.
3. **Schema & Object Conformance**: An exhaustive property-by-property map derived directly from the official MCP JSON Schema (2024-11-05).

### Legend & Tracking Guide
*   **To**: Language -> MCP (Generating MCP Server payloads and handling requests from strongly typed code)
*   **From**: MCP -> Language (Generating MCP Client code, parsing responses, and invoking remote methods)
*   **Presence `[To, From]`**: The object/feature is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object/feature is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the Client architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

## 1. Architectural Integration Layers

This section tracks how the Model Context Protocol is exposed across both the **Generated Artifacts** (the output SDKs/APIs) and the **Generator Tooling** itself (the bidirectional `cdd` compiler/engine).

### 1A. Target/Generated Artifacts
Implementing MCP across the generated output ensures maximum flexibility for the end-user's AI architectures:

*   **CLI Integration (Local Desktop via `stdio`)**: Enables local AI assistants (Claude Desktop, Cursor, Windsurf) to spawn the generated CLI as a subprocess and natively interact with the API locally.
*   **SDK Integration (Programmatic / In-Memory)**: Provides native adapters (e.g., `client.mcp.get_tools()`) so developers can seamlessly attach the generated SDK to frameworks like LangChain, LlamaIndex, or raw LLM clients without network overhead.
*   **Server Integration (Remote AI Gateway via `sse`)**: Generates an AI Gateway endpoint (e.g., `/mcp/sse`), allowing remote, multi-tenant AI agents and web clients to securely consume the API as LLM tools over HTTP.

| Generated Boundary | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **CLI Integration (Local Desktop)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CLI `mcp` Subcommand | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Generates a command (e.g., `app mcp`) to start the server |
| `stdio` Transport Bindings | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Wires stdin/stdout to the generated CLI logic |
| **SDK Integration (Programmatic)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Native MCP Tool Adapter | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | E.g., `client.mcp.get_tools()` mapping SDK methods |
| Native MCP Resource Adapter | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Exposes internal state/docs as MCP resources |
| LLM Execution Router | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Native execution via `client.mcp.execute_tool(name, args)` |
| **Server Integration (Remote / SSE)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SSE Endpoint Generation | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Wires MCP endpoints (e.g. `/mcp/sse`, `/mcp/message`) |
| HTTP Request/Auth Bridging | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Passes standard API auth into the MCP context |
| Dynamic API-to-Tool Proxy | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Resolves incoming tool calls to backend route handlers |

### 1B. Generator/Tooling Artifacts (Meta-MCP)
Exposing the `cdd` bidirectional code generator itself to MCP allows AI models to natively orchestrate code generation, schema manipulation, and code-to-schema extraction.

*   **Generator CLI via `stdio`**: Allows local IDEs or AI agents to directly instruct the generator to scaffold, diff, or compile code across languages (e.g., Tool: `cdd_generate(lang="python")`).
*   **Generator SDK / Core**: Exposes the AST and schema parsing engine natively to MCP, allowing AI tools to dynamically query API specs, understand types, and invoke generator internals in memory.

| Generator Boundary | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Generator CLI (`stdio`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Code Scaffold / Generate Tools | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can invoke standard generator CLI commands via MCP |
| Schema Inspection Tools | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can query loaded OpenAPI/AsyncAPI schemas |
| Bidirectional Sync Tools | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can trigger code-to-schema extraction natively |
| **Generator SDK / Core** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| AST / Type Query Resources | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | AI can read internal AST structures as MCP resources |
| In-Memory Generation Router | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Native bindings to run the generator core directly via MCP |

## 2. Semantic & Conceptual Features

| MCP Feature / Behavior | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Transports** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Standard I/O \(stdio\) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | stdin/stdout message passing |
| **Server-Sent Events (sse)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | HTTP POST + SSE streams |
| **Custom Transports** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Pluggable transport interface |
| **JSON-RPC 2.0 Mechanics** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Message Parsing & Serialization | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Request ID Mapping/Resolution | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Resolving async responses to requests |
| Error Code Mapping \(Standard\) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Codes like -32600, -32603 |
| Notification Handling | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Processing fire-and-forget messages |
| **Connection Lifecycle** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| initialize Handshake Sequence | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Capability negotiation & version matching |
| initialized Acknowledgment | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Sent by client after successful initialization |
| Graceful Disconnect / Close | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Liveness \(ping\) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Periodic connection checks |
| **Request Cancellation (cancelled)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Thread/Task abortion mechanics |
| **Behavioral | **Behavioral & Security** | | | | | Security** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Pagination Cursor Management** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Handling nextCursor fetch loops |
| **Progress Tracking (progress)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Emitting/handling progress events |
| Human-in-the-loop (Sampling) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Prompting user before LLM generation |
| **Human-in-the-loop (Tools)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Security approvals/denials for tool calls |
| **Root Boundary Enforcement** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Preventing traversal outside allowed directories |
| **URI Protocol Handling** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Resolving custom URI schemes |

## 3. Schema & Object Conformance

| Schema Definition / Property | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes |
| :--- | :---: | :---: | :---: | :--- |
| **Annotated** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Annotated** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Annotated** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Annotated** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **BlobResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **BlobResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **BlobResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **BlobResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CallToolRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolRequest (`params`) (`arguments`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolRequest (`params`) (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CallToolResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolResult (`content`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| CallToolResult (`isError`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CancelledNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CancelledNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CancelledNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CancelledNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CancelledNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ClientCapabilities** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ClientCapabilities (`experimental`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ClientCapabilities (`roots`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ClientCapabilities (`roots`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ClientCapabilities (`sampling`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ClientNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ClientRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ClientResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CompleteResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **CreateMessageResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Cursor** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **EmbeddedResource** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| EmbeddedResource (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| EmbeddedResource (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| EmbeddedResource (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| EmbeddedResource (`resource`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| EmbeddedResource (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **EmptyResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **GetPromptRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptRequest (`params`) (`arguments`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptRequest (`params`) (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **GetPromptResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptResult (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| GetPromptResult (`messages`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ImageContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Implementation** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Implementation** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Implementation** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **InitializeRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeRequest (`params`) (`capabilities`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeRequest (`params`) (`clientInfo`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeRequest (`params`) (`protocolVersion`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **InitializeResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeResult (`capabilities`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeResult (`instructions`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeResult (`protocolVersion`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| InitializeResult (`serverInfo`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **InitializedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **InitializedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **InitializedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **InitializedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCError** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCError (`error`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCError (`error`) (`code`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCError (`error`) (`data`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCError (`error`) (`message`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCError (`id`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCError (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCRequest (`id`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCRequest (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCRequest (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCRequest (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **JSONRPCResponse** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCResponse (`id`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCResponse (`jsonrpc`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| JSONRPCResponse (`result`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListPromptsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListPromptsRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListPromptsRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListPromptsRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListPromptsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListPromptsResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListPromptsResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListPromptsResult (`prompts`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListResourceTemplatesRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourceTemplatesRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourceTemplatesRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourceTemplatesRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListResourceTemplatesResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourceTemplatesResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourceTemplatesResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourceTemplatesResult (`resourceTemplates`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListResourcesRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourcesRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourcesRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourcesRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListResourcesResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourcesResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourcesResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListResourcesResult (`resources`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListRootsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListToolsRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListToolsRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListToolsRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListToolsRequest (`params`) (`cursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ListToolsResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListToolsResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListToolsResult (`nextCursor`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ListToolsResult (`tools`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **LoggingLevel** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **LoggingMessageNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| LoggingMessageNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| LoggingMessageNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| LoggingMessageNotification (`params`) (`data`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| LoggingMessageNotification (`params`) (`level`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| LoggingMessageNotification (`params`) (`logger`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelHint** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelHint** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelPreferences** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelPreferences** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelPreferences** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelPreferences** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ModelPreferences** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Notification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Notification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Notification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Notification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PaginatedResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PingRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PingRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PingRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PingRequest (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PingRequest (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ProgressToken** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Prompt** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Prompt (`arguments`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Prompt (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Prompt (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptArgument** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptArgument (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptArgument (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptArgument (`required`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptMessage (`content`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptMessage (`role`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **PromptReference** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptReference (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| PromptReference (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ReadResourceRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ReadResourceRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ReadResourceRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ReadResourceRequest (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ReadResourceResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ReadResourceResult (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ReadResourceResult (`contents`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Request** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Request (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Request (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Request (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Request (`params`) (`_meta`) (`progressToken`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **RequestId** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Resource** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`size`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Resource (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ResourceContents (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ResourceContents (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceReference** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ResourceReference (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ResourceReference (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceTemplate** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceUpdatedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceUpdatedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceUpdatedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ResourceUpdatedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Result** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Result (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Role** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Root** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Root** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Root** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **RootsListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **RootsListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **RootsListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **RootsListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **SamplingMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **SamplingMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **SamplingMessage** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ServerCapabilities** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`experimental`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`logging`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`prompts`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`prompts`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`resources`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`resources`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`resources`) (`subscribe`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`tools`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ServerCapabilities (`tools`) (`listChanged`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ServerNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ServerRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ServerResult** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **SetLevelRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SetLevelRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SetLevelRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SetLevelRequest (`params`) (`level`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **SubscribeRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SubscribeRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SubscribeRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| SubscribeRequest (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **TextContent** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextContent (`annotations`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextContent (`annotations`) (`audience`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextContent (`annotations`) (`priority`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextContent (`text`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextContent (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **TextResourceContents** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextResourceContents (`mimeType`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextResourceContents (`text`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| TextResourceContents (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **Tool** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Tool (`description`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Tool (`inputSchema`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Tool (`inputSchema`) (`properties`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Tool (`inputSchema`) (`required`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Tool (`inputSchema`) (`type`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| Tool (`name`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **ToolListChangedNotification** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ToolListChangedNotification (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ToolListChangedNotification (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| ToolListChangedNotification (`params`) (`_meta`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| **UnsubscribeRequest** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| UnsubscribeRequest (`method`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| UnsubscribeRequest (`params`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
| UnsubscribeRequest (`params`) (`uri`) | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | |
