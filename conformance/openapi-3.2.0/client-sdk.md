# OpenAPI 3.2.0 Conformance Table: Client SDK (HTTP Client + Mocks + Tests)

This table tracks the completeness of language integration with OpenAPI 3.2.0 for Client SDK generation and extraction.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the OpenAPI document from strongly typed client SDKs)
*   **From**: OpenAPI -> Language (Generating HTTP Client code, interfaces, and methods from the OpenAPI document)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the Client architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| OpenAPI 3.2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **OpenAPI Object (Root)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Root generation / parsing |
| **OpenAPI Object (`openapi`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`openapi`) |
| **OpenAPI Object (`$self`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Base URI resolution for internal and external references |
| **OpenAPI Object (`info`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`info`) |
| **OpenAPI Object (`jsonSchemaDialect`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Recognizing custom dialect validation rules locally |
| **OpenAPI Object (`servers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`servers`) |
| **OpenAPI Object (`paths`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`paths`) |
| **OpenAPI Object (`webhooks`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Generating local event/webhook parsing utilities |
| **OpenAPI Object (`components`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`components`) |
| **OpenAPI Object (`security`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`security`) |
| **OpenAPI Object (`tags`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`tags`) |
| **OpenAPI Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OpenAPI Object (`externalDocs`) |
| **Info Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | SDK Header metadata, docstrings, package descriptions |
| **Info Object (`title`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`title`) |
| **Info Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Short package description in package.json/pom.xml |
| **Info Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`description`) |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`termsOfService`) |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`contact`) |
| **Info Object (`license`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`license`) |
| **Info Object (`version`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`version`) |
| **Contact Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Package maintainer info in manifest |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`name`) |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`url`) |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`email`) |
| **License Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Package license generation |
| **License Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for License Object (`name`) |
| **License Object (`identifier`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Package license SPDX field |
| **License Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for License Object (`url`) |
| **Server Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Default Base URL configuration in Client builder |
| **Server Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Server Object (`url`) |
| **Server Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Server Object (`description`) |
| **Server Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Generated as enum/constants for environment selection |
| **Server Object (`variables`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Server Object (`variables`) |
| **Server Variable Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | SDK builder/constructor parameters (e.g. region, env) |
| **Server Variable Object (`enum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Server Variable Object (`enum`) |
| **Server Variable Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Server Variable Object (`default`) |
| **Server Variable Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Server Variable Object (`description`) |
| **Components Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Container for reusable types, interfaces, classes |
| **Components Object (`schemas`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`schemas`) |
| **Components Object (`responses`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`responses`) |
| **Components Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`parameters`) |
| **Components Object (`examples`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`examples`) |
| **Components Object (`requestBodies`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`requestBodies`) |
| **Components Object (`headers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`headers`) |
| **Components Object (`securitySchemes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`securitySchemes`) |
| **Components Object (`links`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`links`) |
| **Components Object (`callbacks`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Components Object (`callbacks`) |
| **Components Object (`pathItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Reusable SDK resource group resolution |
| **Components Object (`mediaTypes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Reusable payload serialization definitions |
| **Paths Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Mapped to top-level client namespaces or groups |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Paths Object (`/{path}`) |
| **Path Item Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Grouping related operations under a single resource |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`$ref`) |
| **Path Item Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`summary`) |
| **Path Item Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`description`) |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`get`) |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`put`) |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`post`) |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`delete`) |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`options`) |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`head`) |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`patch`) |
| **Path Item Object (`trace`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`trace`) |
| **Path Item Object (`query`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | QUERY HTTP method generation |
| **Path Item Object (`additionalOperations`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Custom HTTP method generation |
| **Path Item Object (`servers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`servers`) |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`parameters`) |
| **Operation Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Specific Client methods (e.g., client.users.get(id)) |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`tags`) |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`summary`) |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`description`) |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`externalDocs`) |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`operationId`) |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`parameters`) |
| **Operation Object (`requestBody`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`requestBody`) |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`responses`) |
| **Operation Object (`callbacks`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`callbacks`) |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`deprecated`) |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`security`) |
| **Operation Object (`servers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`servers`) |
| **External Documentation Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Rendered into method/class Javadoc or IDE docstrings |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for External Documentation Object (`description`) |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for External Documentation Object (`url`) |
| **Parameter Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`name`) |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`in`) |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`description`) |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`required`) |
| **Parameter Object (`deprecated`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`deprecated`) |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`allowEmptyValue`) |
| **Parameter Object (`example`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`example`) |
| **Parameter Object (`examples`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`examples`) |
| **Parameter Object (`style`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`style`) |
| **Parameter Object (`explode`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`explode`) |
| **Parameter Object (`allowReserved`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`allowReserved`) |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`schema`) |
| **Parameter Object (`content`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`content`) |
| **Request Body Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Typed request payload object/class argument |
| **Request Body Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Request Body Object (`description`) |
| **Request Body Object (`content`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Request Body Object (`content`) |
| **Request Body Object (`required`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Request Body Object (`required`) |
| **Media Type Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Automatically setting Content-Type / Accept headers |
| **Media Type Object (`schema`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Media Type Object (`schema`) |
| **Media Type Object (`itemSchema`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Strong typing for array items in sequential media types |
| **Media Type Object (`example`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Media Type Object (`example`) |
| **Media Type Object (`examples`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Media Type Object (`examples`) |
| **Media Type Object (`encoding`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Media Type Object (`encoding`) |
| **Media Type Object (`prefixEncoding`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Media Type Object (`prefixEncoding`) |
| **Media Type Object (`itemEncoding`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Media Type Object (`itemEncoding`) |
| **Encoding Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | URL-encoding logic for complex queries, multipart builders |
| **Encoding Object (`contentType`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`contentType`) |
| **Encoding Object (`headers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`headers`) |
| **Encoding Object (`encoding`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`encoding`) |
| **Encoding Object (`prefixEncoding`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`prefixEncoding`) |
| **Encoding Object (`itemEncoding`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`itemEncoding`) |
| **Encoding Object (`style`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`style`) |
| **Encoding Object (`explode`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`explode`) |
| **Encoding Object (`allowReserved`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Encoding Object (`allowReserved`) |
| **Responses Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Return type branching (Success types vs. Error throwing) |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Object (`default`) |
| **Responses Object (`HTTP Status Code`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Object (`HTTP Status Code`) |
| **Response Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Strongly typed response payload class wrapper |
| **Response Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Javadoc/Docstring for specific response branches |
| **Response Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`description`) |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`headers`) |
| **Response Object (`content`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`content`) |
| **Response Object (`links`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`links`) |
| **Callback Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Often skipped in synchronous SDKs |
| **Callback Object (`{expression}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Callback Object (`{expression}`) |
| **Example Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Mock HTTP client generation & unit test fixtures |
| **Example Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`summary`) |
| **Example Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`description`) |
| **Example Object (`dataValue`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`dataValue`) |
| **Example Object (`serializedValue`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`serializedValue`) |
| **Example Object (`externalValue`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`externalValue`) |
| **Example Object (`value`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`value`) |
| **Link Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Fluent method chaining helpers (e.g., resp.getAuthor()) |
| **Link Object (`operationRef`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Link Object (`operationRef`) |
| **Link Object (`operationId`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Link Object (`operationId`) |
| **Link Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Link Object (`parameters`) |
| **Link Object (`requestBody`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Link Object (`requestBody`) |
| **Link Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Link Object (`description`) |
| **Link Object (`server`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Link Object (`server`) |
| **Header Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Exposing typed headers on the Return/Response object |
| **Header Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`description`) |
| **Header Object (`required`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`required`) |
| **Header Object (`deprecated`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`deprecated`) |
| **Header Object (`example`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`example`) |
| **Header Object (`examples`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`examples`) |
| **Header Object (`style`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`style`) |
| **Header Object (`explode`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`explode`) |
| **Header Object (`schema`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`schema`) |
| **Header Object (`content`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`content`) |
| **Tag Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | SDK Namespace grouping (e.g., client.billing.*) |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`name`) |
| **Tag Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`summary`) |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`description`) |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`externalDocs`) |
| **Tag Object (`parent`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Nested client namespaces (e.g., client.billing.invoices) |
| **Tag Object (`kind`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Organizing generated classes by kind |
| **Reference Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Reference Object |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Internal/External type resolution |
| **Reference Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Reference Object (`summary`) |
| **Reference Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Reference Object (`description`) |
| **Schema Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`discriminator`) |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`xml`) |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`externalDocs`) |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`example`) |
| **Discriminator Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Client-side deserialization factories (Polymorphic JSON decoding) |
| **Discriminator Object (`propertyName`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Discriminator Object (`propertyName`) |
| **Discriminator Object (`mapping`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Discriminator Object (`mapping`) |
| **Discriminator Object (`defaultMapping`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Default fallback for polymorphic deserialization |
| **XML Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | XML DOM mapping / Often skipped if JSON-only |
| **XML Object (`nodeType`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Precise XML DOM mapping controls |
| **XML Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`name`) |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`namespace`) |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`prefix`) |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`attribute`) |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`wrapped`) |
| **Security Scheme Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`type`) |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`description`) |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`name`) |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`in`) |
| **Security Scheme Object (`scheme`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`scheme`) |
| **Security Scheme Object (`bearerFormat`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`bearerFormat`) |
| **Security Scheme Object (`flows`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`flows`) |
| **Security Scheme Object (`openIdConnectUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`openIdConnectUrl`) |
| **Security Scheme Object (`oauth2MetadataUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | OAuth2 metadata discovery |
| **Security Scheme Object (`deprecated`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`deprecated`) |
| **OAuth Flows Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Helpers for token exchange requests |
| **OAuth Flows Object (`implicit`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flows Object (`implicit`) |
| **OAuth Flows Object (`password`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flows Object (`password`) |
| **OAuth Flows Object (`clientCredentials`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flows Object (`clientCredentials`) |
| **OAuth Flows Object (`authorizationCode`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flows Object (`authorizationCode`) |
| **OAuth Flows Object (`deviceAuthorization`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Support for the Device Authorization grant flow |
| **OAuth Flow Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | URL discovery for token exchange |
| **OAuth Flow Object (`authorizationUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flow Object (`authorizationUrl`) |
| **OAuth Flow Object (`deviceAuthorizationUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | SDK method for initiating device flow authentication |
| **OAuth Flow Object (`tokenUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flow Object (`tokenUrl`) |
| **OAuth Flow Object (`refreshUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flow Object (`refreshUrl`) |
| **OAuth Flow Object (`scopes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for OAuth Flow Object (`scopes`) |
| **Security Requirement Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Automatic attachment of required auth headers per method |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Requirement Object (`{name}`) |
