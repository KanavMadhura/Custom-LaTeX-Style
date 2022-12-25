import { readFileSync } from 'fs';
import { Plugin, loadMathJax, FileSystemAdapter, Notice } from 'obsidian';
import { toFile } from 'engine/parse';

const STYLE_EDITOR_PATH = "style.md"
const STYLE_PATH = "style.sty"
export default class MyPlugin extends Plugin {

	async onload() {

		// This creates an icon in the left ribbon.
		const ribbonIconEl = this.addRibbonIcon('command', 'Define Custom Math Commands', async (evt: MouseEvent) => {
			
			const md_exists = await this.app.vault.adapter.exists(STYLE_EDITOR_PATH)
			const sty_exists = await this.app.vault.adapter.exists(STYLE_PATH)
			const template = "```\n% Insert Style Information Here\n\n% ===== PACKAGES ===== %\n\n\n\n% ===== COMMANDS ===== %\n\n\n\n% === ENVIRONMENTS === %\n\n\n\n```"
			
			if (!md_exists && !sty_exists) {
				// Create md file
				await this.app.vault.adapter.append(STYLE_EDITOR_PATH, template);
				new Notice("Markdown file created. After desired edits, click the ribbon icon again to generate style file and apply it to MathJax."); 
			} else if (!md_exists && sty_exists) {
				new Notice("Uhh...");
			} else {
				// Update sty file based on md file
				let contents = await this.app.vault.adapter.read(STYLE_EDITOR_PATH);
				await this.app.vault.adapter.write(STYLE_PATH, toFile(contents));
				new Notice("Modified `style.sty` file!");
				// Feed sty file to MathJax
			}
			// View md file in Obsidian
			this.app.workspace.openLinkText(STYLE_EDITOR_PATH, "", true);
		});
	}
}
