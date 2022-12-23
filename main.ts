import { Plugin, loadMathJax } from 'obsidian';

const STYLE_EDITOR_PATH = "style.md"
const STYLE_PATH = "style.sty"
export default class MyPlugin extends Plugin {

	async onload() {

		// This creates an icon in the left ribbon.
		const ribbonIconEl = this.addRibbonIcon('command', 'Define Custom Math Commands', (evt: MouseEvent) => {
			// When the user clicks the icon, a file called style.sty is created at the root of the vault.
			// The file is created if it does not exist, and opened if it does.
			if (!this.app.vault.adapter.exists(STYLE_EDITOR_PATH)) {
				this.app.vault.adapter.write(STYLE_EDITOR_PATH, "");
			}
			this.app.workspace.openLinkText(STYLE_EDITOR_PATH, "", true);
		});
	}
}
