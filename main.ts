import { readFileSync } from 'fs';
import { Plugin, loadMathJax, FileSystemAdapter } from 'obsidian';

const STYLE_EDITOR_PATH = "style.md"
const STYLE_PATH = "style.sty"
export default class MyPlugin extends Plugin {

	async onload() {

		// This creates an icon in the left ribbon.
		const ribbonIconEl = this.addRibbonIcon('command', 'Define Custom Math Commands', async (evt: MouseEvent) => {
			// When the user clicks the icon, a file called style.sty is created at the root of the vault.
			// The file is created if it does not exist, and opened if it does.
			if (! await this.app.vault.adapter.exists(STYLE_EDITOR_PATH)) {
				// write styling_template.txt to style.md
				await this.app.vault.adapter.append(STYLE_EDITOR_PATH, "```\n% Insert Style Information Here\n\n% ===== PACKAGES ===== %\n\n\n\n% ===== COMMANDS ===== %\n\n\n\n% === ENVIRONMENTS === %\n\n\n\n```");
			}
			this.app.workspace.openLinkText(STYLE_EDITOR_PATH, "", true);
		});
	}
}
