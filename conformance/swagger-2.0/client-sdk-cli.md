# Swagger 2.0 Conformance Table: Client SDK CLI (CLI Tooling & Tests)

This table tracks the completeness of language integration with Swagger 2.0 for generating Command-Line Interfaces (CLIs) wrapper tools, and vice-versa.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the Swagger document from declarative CLI structures)
*   **From**: OpenAPI -> Language (Generating CLI routing, flag parsing, and formatting from Swagger)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| Swagger 2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Swagger Object (Root)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (Root) |
| **Swagger Object (`swagger`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`swagger`) |
| **Swagger Object (`info`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`info`) |
| **Swagger Object (`host`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`host`) |
| **Swagger Object (`basePath`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`basePath`) |
| **Swagger Object (`schemes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`schemes`) |
| **Swagger Object (`consumes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`consumes`) |
| **Swagger Object (`produces`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`produces`) |
| **Swagger Object (`paths`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`paths`) |
| **Swagger Object (`definitions`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`definitions`) |
| **Swagger Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`parameters`) |
| **Swagger Object (`responses`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`responses`) |
| **Swagger Object (`securityDefinitions`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`securityDefinitions`) |
| **Swagger Object (`security`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`security`) |
| **Swagger Object (`tags`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`tags`) |
| **Swagger Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`externalDocs`) |
| **Swagger Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Swagger Object (`^x-`) |
| **Info Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object |
| **Info Object (`title`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`title`) |
| **Info Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`description`) |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`termsOfService`) |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`contact`) |
| **Info Object (`license`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`license`) |
| **Info Object (`version`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`version`) |
| **Info Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Info Object (`^x-`) |
| **Contact Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`name`) |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`url`) |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`email`) |
| **Contact Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Contact Object (`^x-`) |
| **License Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for License Object |
| **License Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for License Object (`name`) |
| **License Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for License Object (`url`) |
| **License Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for License Object (`^x-`) |
| **Paths Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Paths Object |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Paths Object (`/{path}`) |
| **Paths Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Paths Object (`^x-`) |
| **Path Item Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`$ref`) |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`get`) |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`put`) |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`post`) |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`delete`) |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`options`) |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`head`) |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`patch`) |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`parameters`) |
| **Path Item Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Path Item Object (`^x-`) |
| **Operation Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`tags`) |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`summary`) |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`description`) |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`externalDocs`) |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`operationId`) |
| **Operation Object (`consumes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`consumes`) |
| **Operation Object (`produces`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`produces`) |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`parameters`) |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`responses`) |
| **Operation Object (`schemes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`schemes`) |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`deprecated`) |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`security`) |
| **Operation Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Operation Object (`^x-`) |
| **External Documentation Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for External Documentation Object |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for External Documentation Object (`description`) |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for External Documentation Object (`url`) |
| **External Documentation Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for External Documentation Object (`^x-`) |
| **Parameter Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`name`) |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`in`) |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`description`) |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`required`) |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`schema`) |
| **Parameter Object (`type`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`type`) |
| **Parameter Object (`format`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`format`) |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`allowEmptyValue`) |
| **Parameter Object (`items`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`items`) |
| **Parameter Object (`collectionFormat`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`collectionFormat`) |
| **Parameter Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`default`) |
| **Parameter Object (`maximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`maximum`) |
| **Parameter Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`exclusiveMaximum`) |
| **Parameter Object (`minimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`minimum`) |
| **Parameter Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`exclusiveMinimum`) |
| **Parameter Object (`maxLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`maxLength`) |
| **Parameter Object (`minLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`minLength`) |
| **Parameter Object (`pattern`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`pattern`) |
| **Parameter Object (`maxItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`maxItems`) |
| **Parameter Object (`minItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`minItems`) |
| **Parameter Object (`uniqueItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`uniqueItems`) |
| **Parameter Object (`enum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`enum`) |
| **Parameter Object (`multipleOf`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`multipleOf`) |
| **Parameter Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameter Object (`^x-`) |
| **Items Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object |
| **Items Object (`type`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`type`) |
| **Items Object (`format`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`format`) |
| **Items Object (`items`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`items`) |
| **Items Object (`collectionFormat`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`collectionFormat`) |
| **Items Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`default`) |
| **Items Object (`maximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`maximum`) |
| **Items Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`exclusiveMaximum`) |
| **Items Object (`minimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`minimum`) |
| **Items Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`exclusiveMinimum`) |
| **Items Object (`maxLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`maxLength`) |
| **Items Object (`minLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`minLength`) |
| **Items Object (`pattern`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`pattern`) |
| **Items Object (`maxItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`maxItems`) |
| **Items Object (`minItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`minItems`) |
| **Items Object (`uniqueItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`uniqueItems`) |
| **Items Object (`enum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`enum`) |
| **Items Object (`multipleOf`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`multipleOf`) |
| **Items Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Items Object (`^x-`) |
| **Responses Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Object |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Object (`default`) |
| **Responses Object (`{HTTP Status Code}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Object (`{HTTP Status Code}`) |
| **Responses Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Object (`^x-`) |
| **Response Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object |
| **Response Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`description`) |
| **Response Object (`schema`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`schema`) |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`headers`) |
| **Response Object (`examples`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`examples`) |
| **Response Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Response Object (`^x-`) |
| **Headers Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Headers Object |
| **Headers Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Headers Object (`{name}`) |
| **Example Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object |
| **Example Object (`{mime type}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Example Object (`{mime type}`) |
| **Header Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object |
| **Header Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`description`) |
| **Header Object (`type`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`type`) |
| **Header Object (`format`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`format`) |
| **Header Object (`items`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`items`) |
| **Header Object (`collectionFormat`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`collectionFormat`) |
| **Header Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`default`) |
| **Header Object (`maximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`maximum`) |
| **Header Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`exclusiveMaximum`) |
| **Header Object (`minimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`minimum`) |
| **Header Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`exclusiveMinimum`) |
| **Header Object (`maxLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`maxLength`) |
| **Header Object (`minLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`minLength`) |
| **Header Object (`pattern`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`pattern`) |
| **Header Object (`maxItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`maxItems`) |
| **Header Object (`minItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`minItems`) |
| **Header Object (`uniqueItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`uniqueItems`) |
| **Header Object (`enum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`enum`) |
| **Header Object (`multipleOf`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`multipleOf`) |
| **Header Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Header Object (`^x-`) |
| **Tag Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`name`) |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`description`) |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`externalDocs`) |
| **Tag Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Tag Object (`^x-`) |
| **Reference Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Reference Object |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Reference Object (`$ref`) |
| **Schema Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object |
| **Schema Object (`$ref`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`$ref`) |
| **Schema Object (`format`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`format`) |
| **Schema Object (`title`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`title`) |
| **Schema Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`description`) |
| **Schema Object (`default`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`default`) |
| **Schema Object (`multipleOf`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`multipleOf`) |
| **Schema Object (`maximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`maximum`) |
| **Schema Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`exclusiveMaximum`) |
| **Schema Object (`minimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`minimum`) |
| **Schema Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`exclusiveMinimum`) |
| **Schema Object (`maxLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`maxLength`) |
| **Schema Object (`minLength`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`minLength`) |
| **Schema Object (`pattern`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`pattern`) |
| **Schema Object (`maxItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`maxItems`) |
| **Schema Object (`minItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`minItems`) |
| **Schema Object (`uniqueItems`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`uniqueItems`) |
| **Schema Object (`maxProperties`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`maxProperties`) |
| **Schema Object (`minProperties`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`minProperties`) |
| **Schema Object (`required`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`required`) |
| **Schema Object (`enum`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`enum`) |
| **Schema Object (`type`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`type`) |
| **Schema Object (`items`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`items`) |
| **Schema Object (`allOf`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`allOf`) |
| **Schema Object (`properties`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`properties`) |
| **Schema Object (`additionalProperties`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`additionalProperties`) |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`discriminator`) |
| **Schema Object (`readOnly`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`readOnly`) |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`xml`) |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`externalDocs`) |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`example`) |
| **Schema Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Schema Object (`^x-`) |
| **XML Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object |
| **XML Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`name`) |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`namespace`) |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`prefix`) |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`attribute`) |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`wrapped`) |
| **XML Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for XML Object (`^x-`) |
| **Definitions Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Definitions Object |
| **Definitions Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Definitions Object (`{name}`) |
| **Parameters Definitions Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameters Definitions Object |
| **Parameters Definitions Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Parameters Definitions Object (`{name}`) |
| **Responses Definitions Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Definitions Object |
| **Responses Definitions Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Responses Definitions Object (`{name}`) |
| **Security Definitions Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Definitions Object |
| **Security Definitions Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Definitions Object (`{name}`) |
| **Security Scheme Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`type`) |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`description`) |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`name`) |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`in`) |
| **Security Scheme Object (`flow`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`flow`) |
| **Security Scheme Object (`authorizationUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`authorizationUrl`) |
| **Security Scheme Object (`tokenUrl`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`tokenUrl`) |
| **Security Scheme Object (`scopes`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`scopes`) |
| **Security Scheme Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Scheme Object (`^x-`) |
| **Scopes Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Scopes Object |
| **Scopes Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Scopes Object (`{name}`) |
| **Scopes Object (`^x-`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Scopes Object (`^x-`) |
| **Security Requirement Object** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Requirement Object |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[x]` , `[x]` | `[x]` , `[x]` | Bidirectional IR, YARD docstring, and AST support for Security Requirement Object (`{name}`) |
