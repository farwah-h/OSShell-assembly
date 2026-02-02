# OSShell — A Minimal DOS-Style Shell in x86 Assembly

![Language: Assembly](https://img.shields.io/badge/language-Assembly-blue)
![Platform: DOS](https://img.shields.io/badge/platform-DOS-lightgrey)
![Project Type: Educational](https://img.shields.io/badge/project--type-Educational-green)

OSShell is a tiny command-line interpreter that brings classic DOS vibes back to life. Written entirely in 16-bit x86 assembly, it demonstrates low-level file-system access, text I/O, and command parsing—all powered by DOS INT 21h calls.

---

## ✨ Key Features

### File Operations

* `type <file name>` — View file contents
* `edit <file name>` — Create or edit text files
* `copy <file name>` — Copy files from source to destination
* `mv <file name>` — Rename files
* `rm <file name>` — Delete files
* `touch <file name>` — Create or update file timestamp

### Directory Operations

* `dir` — List directory contents
* `mkdir <directory name>` — Create directories
* `cd <directory name>` — Change directory
* `rmdir <directory name>` — Remove directories

### System Commands

* `cls` — Clear the screen
* `exit` — Quit OSShell
* `help` — Display built-in help
* `echo <message>` — Display a message on the screen

### Customization

* `bgcolor <0 to 7>` — Change background color
* `fgcolor <0 to 15>` — Change text (foreground) color
* `cursor <0|1|2>` — Change cursor style (0 = block, 1 = underline, 2 = small bar)

### Conditional Command

* `if exist <file name>` — Run next command only if the file exists

---

## 🛠️ Requirements

* **Operating system**: Real DOS (MS-DOS/FreeDOS) or an emulator such as **DOSBox-X** or **PCem**
* **Assembler**: **MASM** (run with `ml final.asm`)
* **Linker**: Automatically handled by `ml`

---

## 🚀 Quick Start

```bat
REM Assemble and Link using ML
ml final.asm

REM Run in DOSBox after mounting
FINAL.EXE
```

### DOSBox Example

```bat
MOUNT C C:\path\to\final.asm
C:
ML FINAL.ASM
FINAL.EXE
```

---

## 📖 Usage

Once you see the prompt:

```
OSShell>
```

type any supported command. For an overview, enter `help`.

```text
OSShell> dir
OSShell> mkdir projects
OSShell> cd projects
OSShell> edit hello.txt
OSShell> type hello.txt
OSShell> bgcolor 1
OSShell> fgcolor 14
OSShell> echo Hello World
OSShell> exit
```

---

## 🔍 Implementation Notes

* **INT 21h** services drive all file, directory, and console operations.
* The command dispatcher converts user input to lowercase and tokenizes it against a command table.
* Memory footprint is deliberately tiny (<10 KiB on disk).
* The built-in editor uses a fixed 80×25 text buffer and supports Insert, Delete, Save, and Quit.

---

## 🎓 Why OSShell?

* Illustrates **system-level programming** without the overhead of an OS SDK.
* Acts as a **live lab** for students learning x86 architecture, interrupt handling, and string manipulation.
* Serves as a **launch pad** for bigger projects—add argument parsing, wildcards, or even loadable plugins!

---

## 🛑 Limitations

* No piping (`|`), redirection (`>`, `<`), or batch scripts
* Minimal error feedback (numeric error codes only)
* The editor is **very** bare-bones (no scrolling or search)
* Assumes FAT12/16 drives—FAT32 is untested

---

## 🤝 Contributing

Pull requests are warmly welcomed:

1. Fork & clone the repo
2. Create a feature branch: `git checkout -b feat/your-topic`
3. Commit your changes with clear messages
4. Push and open a PR describing **what** and **why**

Please follow the coding style in `osshell.asm` (MASM syntax, tab-indented, comment everything!)

---



