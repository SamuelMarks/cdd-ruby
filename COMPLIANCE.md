# OpenAPI Compliance Report

`cdd-ruby` strives for full compliance with [OpenAPI 3.2.0](https://raw.githubusercontent.com/OAI/OpenAPI-Specification/refs/heads/main/versions/3.2.0.md).

Currently supported features:
- Paths, Operations, and Methods
- Request Bodies
- Responses and Response Components
- Schemas (including object, string, boolean types, partially arrays)
- OperationIds, Descriptions, Summaries

Features pending:
- Deep complex polymorphic schemas (anyOf/oneOf/allOf resolution map in Ruby structs)
- Comprehensive OAuth2 Security Schemes / Flows support in generated SDK
- Advanced webhooks

Compliance checks map 1:1 against the AST. We will report when full spec compliance is achieved.
