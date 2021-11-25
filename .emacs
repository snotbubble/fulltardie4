;; the only reason I'm using this geriatric program
(require 'org)
(setq org-auto-renumber-ordered-lists nil)
(global-set-key (kbd "<f10>") 'org-export-dispatch)
(setq org-ascii-text-width 1000)
(setq org-export-initial-scope 'subtree)

;; MELPA
(require 'package)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(package-initialize)

;; red
(load-file "~/.emacs.d/red-mode.el")
(require 'red-mode)
(add-to-list 'auto-mode-alist '("\\.red\\'" . red-mode))
(add-to-list 'magic-mode-alist '("Red [needs: 'view]" . red-mode) )

;; vala
(load-file "~/.emacs.d/vala-mode.el")
(require 'vala-mode)
(add-to-list 'auto-mode-alist '("\\.vala\\'" . vala-mode))

;; syntax highlighting in blocks
(setq org-src-fontify-natively t)

;; scroll = scroll
(setq mouse-wheel-progressive-speed nil)

;; tab = fucking tab,
;; if I want spaces I'll rabbitpunch the fucking spacebar like a fucking retard...
(setq-default indent-tabs-mode t)
(setq-default tab-stop-list (number-sequence 4 200 4))
(setq-default tab-width 4)
(setq-default tab-always-indent t)
(electric-indent-mode 0)
(global-set-key (kbd "<backspace>") 'backward-delete-char)

;; copied from : http://ergoemacs.org/emacs/emacs_tabs_space_indentation_setup.html
;; only thing that actually unbreaks the tab !
;; however it breaks orgmode :(
;; have to use in specific mode hooks
(defun my-insert-tab-char ()
	"Insert a tab char. (ASCII 9, \t)"
	(interactive)
	(insert "\t")
)

;; tab = tab for red
(add-hook 'red-mode-hook
	(lambda ()
		(setq indent-tabs-mode t)
		(setq c-indent 4)
		(setq tab-width 4)
		(local-set-key (kbd "<tab>") 'my-insert-tab-char)
		(local-set-key (kbd "TAB") 'my-insert-tab-char)
	)
)

;; tab = tab for python
(add-hook 'python-mode-hook
	(lambda ()
		(setq indent-tabs-mode t)
		(setq c-indent 4)
		(setq tab-width 4)
		(local-set-key (kbd "<tab>") 'my-insert-tab-char)
		(local-set-key (kbd "TAB") 'my-insert-tab-char)
	)
)

;; tab = tab for vala
(add-hook 'vala-mode-hook
	(lambda ()
		(setq indent-tabs-mode t)
		(setq c-indent 4)
		(setq tab-width 4)
		(local-set-key (kbd "<tab>") 'my-insert-tab-char)
		(local-set-key (kbd "TAB") 'my-insert-tab-char)
		(setq comment-start "//" comment-end   "")
	)
)

;; move lines
;; copied from: https://www.emacswiki.org/emacs/MoveLine
(defun move-line (n)
	"Move the current line up or down by N lines."
	(interactive "p")
	;; (setq col (current-column))
	(beginning-of-line) (setq start (point))
 	(end-of-line) (forward-char) (setq end (point))
 	(let ((line-text (delete-and-extract-region start end)))
  	(forward-line n)
  	(insert line-text)
  	;; restore point to original column in moved line
  	(forward-line -1)
  	;; (forward-char col)
  	)
 )

(defun move-line-up (n)
	"Move the current line up by N lines."
	(interactive "p")
	(move-line (if (null n) -1 (- n))))

(defun move-line-down (n)
  "Move the current line down by N lines."
  (interactive "p")
  (move-line (if (null n) 1 n)))

(global-set-key (kbd "<M-S-mouse-4>") 'move-line-up)
(global-set-key (kbd "<M-S-mouse-5>") 'move-line-down)
(global-set-key (kbd "<M-S-wheel-left>") 'move-line-up)
(global-set-key (kbd "<M-S-wheel-right>") 'move-line-down)

;; highlight word
;; copied from: http://stackoverflow.com/questions/16016893/highlight-occurrences-on-click
(
	defun click-select-word (event)
	(interactive "e")
	(hi-lock-mode 0) 
	(let (
		    ( phrase (concat "\\b" (regexp-quote (thing-at-point 'symbol)) "\\b") )
		) (highlight-regexp phrase)
	)
)

(global-set-key (kbd "<M-S-mouse-1>") 'click-select-word)

;; html export
(setq org-export-html-style-include-scripts nil org-export-html-style-include-default nil)

;; koma-article
(with-eval-after-load "ox-latex"
	(add-to-list 'org-latex-classes 
		'("koma-article" "\\documentclass{scrartcl}"
			("\\section{%s}" . "\\section*{%s}")
			("\\subsection{%s}" . "\\subsection*{%s}")
			("\\subsubsection{%s}" . "\\subsubsection*{%s}")
			("\\paragraph{%s}" . "\\paragraph*{%s}")
			("\\subparagraph{%s}" . "\\subparagraph*{%s}")
		)
	)
)

;; infix calc
(global-set-key (kbd "C-=") 'calculator)

;; save desktop state
(desktop-save-mode 1)

;; hi-line mode -- looks nasty in latest emacs
;; (global-hl-line-mode 0)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-faces-vector
   [default default default italic underline success warning error])
 '(ansi-color-names-vector
   ["#242424" "#e5786d" "#95e454" "#cae682" "#8ac6f2" "#333366" "#ccaa8f" "#f6f3e8"])
 '(custom-enabled-themes '(wombat))
 '(package-selected-packages
   '(highlight-indentation org))
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
