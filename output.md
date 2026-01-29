```
/Users/hirokigoto/git/repos/github.com/togo5/code-to-markdown/src/cli.ts
```

/Users/hirokigoto/git/repos/github.com/togo5/code-to-markdown/src/cli.ts
````ts
#!/usr/bin/env node
import { promises as fsp } from 'node:fs'
import * as path from 'node:path'

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface Options {
	dirs: string[]
	exts: string[] // normalized: [".ts", ".js", ...]
	out: string
	base?: string
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const HELP_TEXT = `
code-to-markdown - Convert source files to a single Markdown document

Usage:
  code-to-markdown --dirs <dir...> --out <file> [options]

Options:
  --dirs <dir...>   Directories to scan (required)
  --out <file>      Output Markdown file path (required)
  --exts <ext...>   File extensions to include (e.g., .ts .js)
  --base <dir>      Base directory for relative paths
  --help            Show this help message

Examples:
  code-to-markdown --dirs src --out output.md
  code-to-markdown --dirs src lib --exts .ts .tsx --out code.md --base .
`.trim()

const LANG_MAP: Record<string, string> = {
	'.py': 'python',
	'.js': 'js',
	'.ts': 'ts',
	'.tsx': 'tsx',
	'.jsx': 'jsx',
	'.java': 'java',
	'.kt': 'kotlin',
	'.c': 'c',
	'.h': 'c',
	'.cpp': 'cpp',
	'.hpp': 'cpp',
	'.cs': 'csharp',
	'.go': 'go',
	'.rs': 'rust',
	'.rb': 'ruby',
	'.php': 'php',
	'.swift': 'swift',
	'.scala': 'scala',
	'.sh': 'bash',
	'.zsh': 'zsh',
	'.ps1': 'powershell',
	'.json': 'json',
	'.yml': 'yaml',
	'.yaml': 'yaml',
	'.toml': 'toml',
	'.ini': 'ini',
	'.md': 'md',
	'.txt': 'text',
	'.html': 'html',
	'.htm': 'html',
	'.css': 'css',
	'.scss': 'scss',
	'.sql': 'sql',
	'.xml': 'xml',
}

function normalizeExts(exts: string[]): string[] {
	const norm = exts
		.map((e) => e.trim())
		.filter(Boolean)
		.map((e) => (e.startsWith('.') ? e : `.${e}`))
		.map((e) => e.toLowerCase())
	return Array.from(new Set(norm)).sort()
}

function guessLang(filePath: string): string {
	const base = path.basename(filePath).toLowerCase()
	if (base === 'dockerfile') return 'dockerfile'
	if (base === 'makefile') return 'makefile'
	const ext = path.extname(filePath).toLowerCase()
	return LANG_MAP[ext] ?? ext.replace(/^\./, '')
}

async function isBinaryFile(
	filePath: string,
	sniffBytes = 4096,
): Promise<boolean> {
	try {
		const fh = await fsp.open(filePath, 'r')
		try {
			const buf = Buffer.alloc(sniffBytes)
			const { bytesRead } = await fh.read(buf, 0, sniffBytes, 0)
			for (let i = 0; i < bytesRead; i++) {
				if (buf[i] === 0) return true // NUL
			}
			return false
		} finally {
			await fh.close()
		}
	} catch {
		return true
	}
}

function toRelPosix(filePath: string, baseDir?: string): string {
	let p = filePath
	if (baseDir) {
		const rel = path.relative(baseDir, filePath)
		// baseDir外なら相対が "../" になるのでそのまま出す（仕様）
		p = rel
	}
	return p.split(path.sep).join('/')
}

async function walk(dir: string): Promise<string[]> {
	const out: string[] = []
	const stack: string[] = [dir]

	while (stack.length) {
		const cur = stack.pop()!
		try {
			const entries = await fsp.readdir(cur, { withFileTypes: true })
			for (const ent of entries) {
				const full = path.join(cur, ent.name)
				if (ent.isDirectory()) stack.push(full)
				else if (ent.isFile()) out.push(full)
			}
		} catch {}
	}
	return out
}

async function findFiles(
	dirs: string[],
	exts: string[],
	baseDir?: string,
): Promise<string[]> {
	const all: string[] = []
	for (const d of dirs) {
		try {
			const st = await fsp.stat(d)
			if (!st.isDirectory()) continue
		} catch {
			continue
		}

		const files = await walk(d)
		for (const f of files) {
			if (exts.length > 0) {
				const ext = path.extname(f).toLowerCase()
				if (!exts.includes(ext)) continue
			}
			all.push(f)
		}
	}

	const key = (p: string) => toRelPosix(p, baseDir)
	all.sort((a, b) => key(a).localeCompare(key(b)))
	return all
}

function pickFence(content: string): string {
	// content内に ``` があれば ```` にする（簡易）
	return content.includes('```') ? '````' : '```'
}

async function readTextSafely(filePath: string): Promise<string> {
	try {
		return await fsp.readFile(filePath, 'utf8')
	} catch {
		// どうしても読めない場合はバイナリ扱いに寄せる
		return ''
	}
}

async function buildMarkdown(
	files: string[],
	baseDir?: string,
): Promise<string> {
	const lines: string[] = []

	// file list
	lines.push('```')
	for (const f of files) lines.push(toRelPosix(f, baseDir))
	lines.push('```')
	lines.push('')

	for (const f of files) {
		const rel = toRelPosix(f, baseDir)

		if (await isBinaryFile(f)) {
			lines.push(rel)
			lines.push('```text')
			lines.push('[Skipped: binary file]')
			lines.push('```')
			lines.push('')
			continue
		}

		const lang = guessLang(f)
		const content = await readTextSafely(f)

		const fence = pickFence(content)
		lines.push(rel)
		lines.push(`${fence}${lang}`)
		lines.push(content.replace(/\r\n/g, '\n').replace(/\n$/, '')) // 末尾改行は整形
		lines.push(fence)
		lines.push('')
	}

	return lines.join('\n').replace(/\s+$/, '') + '\n'
}

function parseArgs(argv: string[]): Options | null {
	if (argv.includes('--help') || argv.includes('-h') || argv.length === 0) {
		console.log(HELP_TEXT)
		return null
	}

	const getMany = (flag: string): string[] => {
		const i = argv.indexOf(flag)
		if (i === -1) return []
		const vals: string[] = []
		for (let j = i + 1; j < argv.length; j++) {
			if (argv[j].startsWith('--')) break
			vals.push(argv[j])
		}
		return vals
	}

	const getOne = (flag: string): string | undefined => {
		const i = argv.indexOf(flag)
		if (i === -1) return undefined
		const v = argv[i + 1]
		if (!v || v.startsWith('--')) return undefined
		return v
	}

	const dirs = getMany('--dirs')
	if (dirs.length === 0) {
		throw new Error(
			'Missing required option: --dirs <dir...>\nRun with --help for usage information.',
		)
	}

	const out = getOne('--out')
	if (!out) {
		throw new Error(
			'Missing required option: --out <file>\nRun with --help for usage information.',
		)
	}

	const exts = normalizeExts(getMany('--exts'))
	const base = getOne('--base')

	return { dirs, exts, out, base }
}

async function main(): Promise<void> {
	const args = parseArgs(process.argv.slice(2))
	if (!args) return

	const dirsAbs = args.dirs.map((d) => path.resolve(d))
	const outAbs = path.resolve(args.out)
	const baseAbs = args.base ? path.resolve(args.base) : undefined

	const files = await findFiles(dirsAbs, args.exts, baseAbs)
	if (files.length === 0) {
		console.warn('Warning: No matching files found.')
	}

	const md = await buildMarkdown(files, baseAbs)

	await fsp.mkdir(path.dirname(outAbs), { recursive: true })
	await fsp.writeFile(outAbs, md, 'utf8')
	console.log(`Generated: ${outAbs} (${files.length} files)`)
}

main().catch((err) => {
	console.error(err?.message ?? err)
	process.exit(1)
})
````
