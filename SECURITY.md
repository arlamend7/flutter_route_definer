# Security

Client-side route guards are a user-interface control. Applications must enforce authentication and authorization on their servers and must treat URLs, restored browser state and navigation arguments as untrusted input. Do not put credentials or sensitive records in URLs/history state. Diagnostic callbacks are application-owned; redact secrets before logging them.

For a suspected authorization bypass or other vulnerability, use GitHub's private vulnerability reporting option in this repository's Security tab if it is enabled. If it is unavailable, open an issue asking the maintainer for a private reporting channel without including exploit details or private data. Do not send credentials, tokens or customer information.

Include the affected package/Flutter versions, a minimal reproduction with synthetic data, the impact and any proposed mitigation. Security fixes target the currently maintained major release; support for older major releases is assessed individually. Publication of a security fix requires the same release validation as other changes.
