use zed_extension_api as zed;

struct HyperqlExtension;

impl zed::Extension for HyperqlExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> zed::Result<zed::Command> {
        let path = worktree
            .which("hyperql-lsp")
            .ok_or_else(|| "hyperql-lsp not found in PATH. Please install the HyperQL LSP server.".to_string())?;

        Ok(zed::Command {
            command: path,
            args: vec![],
            env: vec![],
        })
    }
}

zed::register_extension!(HyperqlExtension);
