# ==============================================================================
#  Linux CLI Interactive Course — Makefile
# ==============================================================================

SHELL         := /bin/bash
MISSIONS_DIR  := missions
PROJECTS_DIR  := projects
PROGRESS_FILE := progress.md
LAB_DIR       := lab

MISSION_DIRS  := $(sort $(wildcard $(MISSIONS_DIR)/*/))
TOTAL         := $(words $(MISSION_DIRS))
PAGER         := $(shell command -v bat 2>/dev/null || command -v less 2>/dev/null || echo cat)

# ── ANSI codes ────────────────────────────────────────────────────────────────
B  := \033[1m
D  := \033[2m
R  := \033[0m
RD := \033[31m
GR := \033[32m
YL := \033[33m
BL := \033[34m
MG := \033[35m
CY := \033[36m

.PHONY: help start status mission exercises practice review next hint check solution done \
        project lab _require_n _pad

# ── help ─────────────────────────────────────────────────────────────────────

help:
	@printf "\n"
	@printf "$(B)$(CY)  ╔══════════════════════════════════════════════════════════╗$(R)\n"
	@printf "$(B)$(CY)  ║$(R)         $(B)LINUX CLI INTERACTIVE COURSE$(R)                     $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)         $(D)17 missions  ·  4 projects  ·  terminal only$(R)     $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ╠══════════════════════════════════════════════════════════╣$(R)\n"
	@printf "$(B)$(CY)  ║$(R)                                                          $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)  $(B)NAVIGATION$(R)                                             $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make start$(R)               Begin at Mission 01        $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make status$(R)              Visual progress board      $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make next$(R)                Open next unfinished       $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)                                                          $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)  $(B)MISSIONS$(R)                                               $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make practice  N=03$(R)      $(B)Interactive shell session$(R)    $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make mission   N=03$(R)      Read the concept brief     $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make exercises N=03$(R)      Open hands-on exercises    $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make review    N=03$(R)      Replay concepts only       $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make hint      N=03$(R)      Get a nudge                $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make check     N=03$(R)      See self-check steps       $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make solution  N=03$(R)      Reveal solution (confirm)  $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make done      N=03$(R)      Mark mission complete      $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)                                                          $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)  $(B)PROJECTS & SANDBOX$(R)                                     $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make project   N=1$(R)       Open weekly mini-project   $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)    $(GR)make lab$(R)                 List your sandbox          $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ║$(R)                                                          $(B)$(CY)║$(R)\n"
	@printf "$(B)$(CY)  ╚══════════════════════════════════════════════════════════╝$(R)\n"
	@printf "\n"

# ── start ─────────────────────────────────────────────────────────────────────

start:
	@clear
	@printf "\n"
	@printf "$(B)$(CY)      ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗$(R)\n"
	@printf "$(B)$(CY)      ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝$(R)\n"
	@printf "$(B)$(CY)      ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ $(R)\n"
	@printf "$(B)$(CY)      ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ $(R)\n"
	@printf "$(B)$(CY)      ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗$(R)\n"
	@printf "$(B)$(CY)      ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝$(R)\n"
	@printf "\n"
	@printf "      $(B)LINUX CLI INTERACTIVE COURSE$(R)\n"
	@printf "      $(D)17 Missions  ·  4 Projects  ·  Terminal Only$(R)\n"
	@printf "\n"
	@printf "      ${D}Each mission:  read brief → practice in shell → mark done${R}\n"
	@printf "\n"
	@printf "      Press $(B)Enter$(R) to begin Mission 01 practice ...\n"
	@read _ignored
	@$(MAKE) --no-print-directory practice N=01

# ── status ────────────────────────────────────────────────────────────────────

status:
	@printf "\n"
	@printf "  $(B)MISSION PROGRESS$(R)\n"
	@printf "  $(D)──────────────────────────────────────────────────────$(R)\n"
	@printf "\n"
	@seen_next=false; \
	for dir in $(MISSION_DIRS); do \
		num=$$(basename $$dir | cut -d'-' -f1); \
		name=$$(basename $$dir | sed 's/^[0-9]*-//' | tr '-' ' '); \
		if grep -q "^DONE:$$num" $(PROGRESS_FILE) 2>/dev/null; then \
			printf "  $(GR)✓$(R)  $(D)%-4s$(R)  $(D)%-34s$(R)  $(D)done$(R)\n" "$$num" "$$name"; \
		elif [ "$$seen_next" = false ]; then \
			printf "  $(B)$(YL)→$(R)  $(B)%-4s  %-34s$(R)  $(YL)← up next$(R)\n" "$$num" "$$name"; \
			seen_next=true; \
		else \
			printf "  $(D)·  %-4s  %-34s$(R)\n" "$$num" "$$name"; \
		fi; \
	done
	@printf "\n"
	@printf "  $(D)──────────────────────────────────────────────────────$(R)\n"
	@completed=0; \
	[ -f "$(PROGRESS_FILE)" ] && completed=$$(grep -c "^DONE:" $(PROGRESS_FILE)); \
	pct=$$(($$completed * 100 / $(TOTAL))); \
	filled=$$(($$completed * 28 / $(TOTAL))); \
	empty=$$((28 - $$filled)); \
	bar=""; for i in $$(seq 1 $$filled 2>/dev/null); do bar="$${bar}█"; done; \
	emp=""; for i in $$(seq 1 $$empty 2>/dev/null); do emp="$${emp}░"; done; \
	printf "  $(GR)$$bar$(D)$$emp$(R)  $(B)$$completed$(R)/$(TOTAL)  $(D)($$pct%%)$(R)\n"
	@printf "\n"

# ── _require_n / _pad ─────────────────────────────────────────────────────────

_require_n:
ifndef N
	$(error Specify a mission number: make <target> N=03)
endif

_pad:
	$(eval PADDED := $(shell printf '%02d' $(N)))

# ── mission ───────────────────────────────────────────────────────────────────

mission: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)  Run '$(GR)make status$(R)' to list missions.\n\n"; \
		exit 1; \
	fi; \
	name=$$(basename $$dir | sed 's/^[0-9]*-//' | tr '-' ' '); \
	if grep -q "^DONE:$(PADDED)" $(PROGRESS_FILE) 2>/dev/null; then \
		badge="$(GR)  complete  $(R)"; \
	else \
		badge="$(YL)  in progress$(R)"; \
	fi; \
	printf "\n"; \
	printf "$(B)$(CY)  ┌──────────────────────────────────────────────────────┐$(R)\n"; \
	printf "$(B)$(CY)  │$(R)  $(B)MISSION $(PADDED)$(R)  ·  %-36s$(B)$(CY)│$(R)\n" "$$name"; \
	printf "$(B)$(CY)  │$(R)  Status: $$badge$(B)$(CY)                                 │$(R)\n"; \
	printf "$(B)$(CY)  ├──────────────────────────────────────────────────────┤$(R)\n"; \
	printf "$(B)$(CY)  │$(R)  $(GR)make exercises N=$(PADDED)$(R)  · start the exercises          $(B)$(CY)│$(R)\n"; \
	printf "$(B)$(CY)  │$(R)  $(GR)make hint      N=$(PADDED)$(R)  · get a nudge                 $(B)$(CY)│$(R)\n"; \
	printf "$(B)$(CY)  │$(R)  $(GR)make done      N=$(PADDED)$(R)  · mark as complete            $(B)$(CY)│$(R)\n"; \
	printf "$(B)$(CY)  └──────────────────────────────────────────────────────┘$(R)\n"; \
	printf "\n"; \
	$(PAGER) "$$dir/README.md"

# ── exercises ─────────────────────────────────────────────────────────────────

exercises: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)\n\n"; exit 1; \
	fi; \
	file="$$dir/exercises.md"; \
	if [ ! -f "$$file" ]; then \
		printf "\n  $(RD)✗  exercises.md not found for Mission $(PADDED).$(R)\n\n"; exit 1; \
	fi; \
	name=$$(basename $$dir | sed 's/^[0-9]*-//' | tr '-' ' '); \
	printf "\n"; \
	printf "$(B)$(YL)  ┌─ EXERCISES$(R)  $(D)·  Mission $(PADDED)  ·  $$name$(R)\n"; \
	printf "$(YL)  │$(R)\n"; \
	printf "$(YL)  │$(R)  $(D)Complete each exercise, then run:$(R)  $(GR)make done N=$(PADDED)$(R)\n"; \
	printf "$(YL)  │$(R)  $(D)Stuck? Try:$(R)  $(GR)make hint N=$(PADDED)$(R)  $(D)or$(R)  $(GR)make solution N=$(PADDED)$(R)\n"; \
	printf "$(YL)  └───────────────────────────────────────────────────────$(R)\n"; \
	printf "\n"; \
	$(PAGER) "$$file"

# ── practice ─────────────────────────────────────────────────────────────────

practice: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)\n\n"; exit 1; \
	fi; \
	script="$$dir/practice.sh"; \
	if [ ! -f "$$script" ]; then \
		printf "\n  $(RD)✗  practice.sh not found for Mission $(PADDED).$(R)\n\n"; exit 1; \
	fi; \
	name=$$(basename $$dir | sed 's/^[0-9]*-//' | tr '-' ' '); \
	printf "\n$(B)$(GR)  Starting interactive practice for Mission $(PADDED) · $$name$(R)\n\n"; \
	bash "$$script"

# ── review ────────────────────────────────────────────────────────────────────
# Opens the mission brief and exercises side by side in the pager

review: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)\n\n"; exit 1; \
	fi; \
	name=$$(basename $$dir | sed 's/^[0-9]*-//' | tr '-' ' '); \
	printf "\n"; \
	printf "$(B)$(MG)  ┌─ REVIEW · Mission $(PADDED) · $$name$(R)\n"; \
	printf "$(MG)  │$(R)\n"; \
	printf "$(MG)  │$(R)  Showing: brief → exercises → solution (in pager)\n"; \
	printf "$(MG)  │$(R)  Navigate with arrow keys · Press $(B)q$(R) to quit\n"; \
	printf "$(MG)  └───────────────────────────────────────────────────────$(R)\n\n"; \
	files=""; \
	[ -f "$$dir/README.md"    ] && files="$$files $$dir/README.md" \
	                            || printf "$(MG)  │$(R)  $(D)README.md    — not yet written$(R)\n"; \
	[ -f "$$dir/exercises.md" ] && files="$$files $$dir/exercises.md" \
	                            || printf "$(MG)  │$(R)  $(D)exercises.md — not yet written$(R)\n"; \
	[ -f "$$dir/solution.md"  ] && files="$$files $$dir/solution.md" \
	                            || printf "$(MG)  │$(R)  $(D)solution.md  — not yet written$(R)\n"; \
	[ -z "$$files" ] && { printf "$(MG)  └───────────────────────────────────────────────────────$(R)\n\n"; exit 0; }; \
	$(PAGER) $$files

# ── hint ──────────────────────────────────────────────────────────────────────

hint: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)\n\n"; exit 1; \
	fi; \
	file="$$dir/exercises.md"; \
	if [ ! -f "$$file" ]; then \
		printf "\n  $(YL)  Hints for Mission $(PADDED) are not available yet.$(R)\n"; \
		printf "  $(D)exercises.md has not been written for this mission.$(R)\n\n"; \
		exit 0; \
	fi; \
	printf "\n"; \
	printf "$(B)$(YL)  ┌─ HINTS  ·  Mission $(PADDED)$(R)\n"; \
	printf "$(YL)  │$(R)\n"; \
	grep -n "\*\*Hint" "$$file" | while IFS=: read lnum content; do \
		printf "$(YL)  │$(R)  $(B)$(YL)▸$(R)  %s\n" "$$(echo $$content | sed 's/\*\*Hint[^:]*:\*\*//')"; \
	done; \
	total=$$(grep -c "\*\*Hint" "$$file" 2>/dev/null || echo 0); \
	[ "$$total" -eq 0 ] && printf "$(YL)  │$(R)  $(D)No explicit hints in exercises.md$(R)\n"; \
	printf "$(YL)  └───────────────────────────────────────────────────────$(R)\n"; \
	printf "\n"

# ── check ─────────────────────────────────────────────────────────────────────

check: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)\n\n"; exit 1; \
	fi; \
	file="$$dir/exercises.md"; \
	if [ ! -f "$$file" ]; then \
		printf "\n  $(RD)✗  exercises.md not found for Mission $(PADDED).$(R)\n\n"; exit 1; \
	fi; \
	printf "\n"; \
	printf "$(B)$(CY)  ┌─ SELF-CHECKS  ·  Mission $(PADDED)$(R)\n"; \
	printf "$(CY)  │$(R)\n"; \
	grep -n "\*\*Self-check" "$$file" | while IFS=: read lnum content; do \
		printf "$(CY)  │$(R)  $(B)$(CY)▸$(R)  %s\n" "$$(echo $$content | sed 's/\*\*Self-check[^:]*:\*\*//')"; \
	done; \
	total=$$(grep -c "\*\*Self-check" "$$file" 2>/dev/null || echo 0); \
	[ "$$total" -eq 0 ] && printf "$(CY)  │$(R)  $(D)No self-checks found in exercises.md$(R)\n"; \
	printf "$(CY)  └───────────────────────────────────────────────────────$(R)\n"; \
	printf "\n"

# ── solution ──────────────────────────────────────────────────────────────────

solution: _require_n _pad
	@dir=$$(ls -d $(MISSIONS_DIR)/$(PADDED)-* 2>/dev/null | head -1); \
	if [ -z "$$dir" ]; then \
		printf "\n  $(RD)✗  Mission $(PADDED) not found.$(R)\n\n"; exit 1; \
	fi; \
	file="$$dir/solution.md"; \
	if [ ! -f "$$file" ]; then \
		printf "\n  $(YL)  Solution for Mission $(PADDED) is not available yet.$(R)\n"; \
		printf "  $(D)solution.md has not been written for this mission.$(R)\n\n"; \
		exit 0; \
	fi; \
	printf "\n"; \
	printf "  $(B)$(YL)⚠  Revealing the solution for Mission $(PADDED).$(R)\n"; \
	printf "  $(D)Try for at least 10 more minutes before peeking.$(R)\n"; \
	printf "\n"; \
	printf "  Reveal anyway? $(B)[y/N]$(R) "; \
	read confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		printf "\n"; \
		printf "$(B)$(RD)  ┌─ SOLUTION  ·  Mission $(PADDED)  ·  read carefully$(R)\n"; \
		printf "$(RD)  │$(R)\n"; \
		$(PAGER) "$$file"; \
	else \
		printf "\n  $(GR)Good call. Keep pushing — you've got this.$(R)\n\n"; \
	fi

# ── done ──────────────────────────────────────────────────────────────────────

done: _require_n _pad
	@if grep -q "^DONE:$(PADDED)" $(PROGRESS_FILE) 2>/dev/null; then \
		printf "\n  $(YL)Mission $(PADDED) is already marked complete.$(R)\n\n"; \
	else \
		echo "DONE:$(PADDED) $$(date '+%Y-%m-%d %H:%M')" >> $(PROGRESS_FILE); \
		next=""; nextname=""; \
		for dir in $(MISSION_DIRS); do \
			num=$$(basename $$dir | cut -d'-' -f1); \
			if ! grep -q "^DONE:$$num" $(PROGRESS_FILE) 2>/dev/null; then \
				next=$$num; \
				nextname=$$(basename $$dir | sed 's/^[0-9]*-//' | tr '-' ' '); \
				break; \
			fi; \
		done; \
		completed=0; [ -f "$(PROGRESS_FILE)" ] && completed=$$(grep -c "^DONE:" $(PROGRESS_FILE)); \
		printf "\n"; \
		printf "$(B)$(GR)  ┌──────────────────────────────────────────────────────┐$(R)\n"; \
		printf "$(B)$(GR)  │$(R)  $(B)✓  MISSION $(PADDED) COMPLETE$(R)                              $(B)$(GR)│$(R)\n"; \
		printf "$(B)$(GR)  └──────────────────────────────────────────────────────┘$(R)\n"; \
		printf "\n"; \
		printf "     Completed  $(D)$$(date '+%Y-%m-%d at %H:%M')$(R)\n"; \
		printf "     Progress   $(B)$$completed$(R) / $(TOTAL) missions\n"; \
		if [ -n "$$next" ]; then \
			printf "\n"; \
			printf "     Next up    $(B)Mission $$next$(R)  ·  $$nextname\n"; \
			printf "                $(D)Run:$(R)  $(GR)make next$(R)\n"; \
		else \
			printf "\n"; \
			printf "  $(B)$(GR)  All $(TOTAL) missions complete!$(R)\n"; \
			printf "     Start a weekly project:  $(GR)make project N=1$(R)\n"; \
		fi; \
		printf "\n"; \
	fi

# ── next ──────────────────────────────────────────────────────────────────────

next:
	@next=""; \
	for dir in $(MISSION_DIRS); do \
		num=$$(basename $$dir | cut -d'-' -f1); \
		if ! grep -q "^DONE:$$num" $(PROGRESS_FILE) 2>/dev/null; then \
			next=$$num; break; \
		fi; \
	done; \
	if [ -z "$$next" ]; then \
		printf "\n"; \
		printf "  $(B)$(GR)All $(TOTAL) missions complete!$(R)\n\n"; \
		printf "  $(D)Start a weekly project:$(R)\n\n"; \
		printf "    $(GR)make project N=1$(R)  $(D)·$(R)  Log Analyzer\n"; \
		printf "    $(GR)make project N=2$(R)  $(D)·$(R)  Backup Script\n"; \
		printf "    $(GR)make project N=3$(R)  $(D)·$(R)  User Audit Report\n"; \
		printf "    $(GR)make project N=4$(R)  $(D)·$(R)  Dotfiles Setup\n"; \
		printf "\n"; \
	else \
		$(MAKE) --no-print-directory practice N=$$next; \
	fi

# ── project ───────────────────────────────────────────────────────────────────

project: _require_n
	@matched=$$(ls -d $(PROJECTS_DIR)/p$(N)-* 2>/dev/null | head -1); \
	if [ -z "$$matched" ]; then \
		printf "\n  $(RD)✗  Project $(N) not found.$(R)  Check $(PROJECTS_DIR)/\n\n"; \
		exit 1; \
	fi; \
	file="$$matched/README.md"; \
	if [ ! -f "$$file" ]; then \
		printf "\n  $(RD)✗  README.md not found — project not built yet.$(R)\n\n"; \
		exit 1; \
	fi; \
	name=$$(basename $$matched | sed 's/^p[0-9]*-//' | tr '-' ' '); \
	printf "\n"; \
	printf "$(B)$(MG)  ┌─ PROJECT $(N)$(R)  $(D)·$(R)  $(B)$$name$(R)\n"; \
	printf "$(MG)  │$(R)\n"; \
	printf "$(MG)  │$(R)  $(D)When done, run:$(R)  $(GR)make done N=P$(N)$(R)\n"; \
	printf "$(MG)  └───────────────────────────────────────────────────────$(R)\n"; \
	printf "\n"; \
	$(PAGER) "$$file"

# ── lab ───────────────────────────────────────────────────────────────────────

lab:
	@printf "\n"
	@printf "$(B)$(BL)  ┌─ LAB SANDBOX$(R)  $(D)·  $(LAB_DIR)/$(R)\n"
	@printf "$(BL)  │$(R)\n"
	@if [ -z "$$(ls -A $(LAB_DIR)/ 2>/dev/null)" ]; then \
		printf "$(BL)  │$(R)  $(D)(empty — your sandbox awaits)$(R)\n"; \
	else \
		ls -alFh $(LAB_DIR)/ | tail -n +2 | while read line; do \
			printf "$(BL)  │$(R)  %s\n" "$$line"; \
		done; \
	fi
	@printf "$(BL)  │$(R)\n"
	@printf "$(BL)  │$(R)  $(D)Tip:$(R)  cd $(LAB_DIR)/  — experiment freely, nothing here matters\n"
	@printf "$(BL)  └───────────────────────────────────────────────────────$(R)\n"
	@printf "\n"
