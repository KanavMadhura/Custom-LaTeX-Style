import { readFileSync } from 'fs';
import { Plugin, loadMathJax, FileSystemAdapter, Notice, renderMath, finishRenderMath } from 'obsidian';
import { toFile } from 'engine/engine';

const STYLE_EDITOR_PATH = "style.md"
const STYLE_PATH = "style.sty"
export default class MyPlugin extends Plugin {

	async onload() {
		await loadMathJax();
		// This creates an icon in the left ribbon.
		const ribbonIconEl = this.addRibbonIcon('command', 'Load declarations in style file', async (evt: MouseEvent) => {
			
			const md_exists = await this.app.vault.adapter.exists(STYLE_EDITOR_PATH);
			const template = "```\n% Insert Style Information Here\n\n% ===== COMMANDS ===== %\n\n\n\n% === ENVIRONMENTS === %\n\n\n\n```";
			
			if (!md_exists) {
				// Create md file
				await this.app.vault.adapter.append(STYLE_EDITOR_PATH, template);
				new Notice("Markdown file created. After desired edits, click the ribbon icon again to generate style file and apply it to MathJax."); 
			} else {
				// Update sty file based on md file
				let contents = await this.app.vault.adapter.read(STYLE_EDITOR_PATH);
				let declarations = await toFile(contents);
				await renderMath(declarations, false);
				await finishRenderMath();
				new Notice("Declared all macros - you may now use them in your files.");
				// Feed macros to MathJax

			}
			// View md file in Obsidian
			this.app.workspace.openLinkText(STYLE_EDITOR_PATH, "", true);
		});
	}
}
