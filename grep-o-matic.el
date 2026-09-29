;;; grep-o-matic.el --- Grep word-at-point in repo, directory, or open files  -*- lexical-binding: t; -*-

;; Copyright (C) 2008-2021 Avi Rozen
;; Copyright (C) 2026 Jai G (modernized rewrite)

;; Author: Jai G
;; Original-Author: Avi Rozen <avi.rozen@gmail.com>
;; URL: https://github.com/jaig-in/emacs-grep-a-lot
;; Version: 2.0.0
;; Keywords: tools, processes, search
;; Package-Requires: ((emacs "28.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A modernized rewrite of grep-o-matic 1.0.7 by Avi Rozen
;; (https://github.com/ZungBang/emacs-grep-o-matic).
;;
;; One key to search for the word under the cursor:
;;   `grep-o-matic-repository'       — in the project/repo root
;;   `grep-o-matic-current-directory' — in the current directory, recursively
;;   `grep-o-matic-visited-files'    — across all visited file buffers
;;
;; With C-u prefix, prompts for the search regexp instead.
;;
;; Uses `rgrep' for directory/repo searches and `grep' for visited files,
;; so all results land in `grep-mode' buffers.  Works with grep-a-lot for
;; multiple named result buffers.
;;
;; Part of the grep-a-lot suite:
;;   grep-a-lot   — multiple named search buffers + ring navigation
;;   grep-o-matic — word-at-point grep via rgrep (this file)
;;   rg-o-matic   — word-at-point search via ripgrep
;;
;; Changes from the original 1.x:
;; - Uses `project-root' / `vc-root-dir' instead of repository-root.el.
;; - Dropped igrep support.
;; - Lexical binding, cl-lib.
;; - File pattern detection simplified.
;;
;; Usage:
;;   (require 'grep-o-matic)
;;   (grep-o-matic-setup-keys)   ; optional — binds M-] / . , prefix
;;
;; If you also use rg-o-matic, it defaults to M-\ to avoid collision.

;;; Code:

(require 'grep)
(require 'vc)
(require 'cl-lib)

(defgroup grep-o-matic nil
  "Grep word-at-point in repo, directory, or open files."
  :group 'grep
  :group 'convenience
  :prefix "grep-o-matic-")

(defcustom grep-o-matic-search-patterns
  '("*.cpp" "*.c" "*.h" "*.hpp" "*.cc" "*.cxx"
    "*.py" "*.rb" "*.pl" "*.sh" "*.bash"
    "*.el" "*.clj" "*.cljs"
    "*.js" "*.ts" "*.jsx" "*.tsx" "*.vue" "*.svelte"
    "*.java" "*.kt" "*.scala" "*.go" "*.rs" "*.zig"
    "*.html" "*.css" "*.scss" "*.less"
    "*.org" "*.md" "*.txt" "*.yml" "*.yaml" "*.toml" "*.json"
    "[Mm]akefile" "*.mk" "*.cmake"
    "Dockerfile" "*.tf")
  "File glob patterns for grep-o-matic searches.
If the current file's extension does not match any of these patterns,
the search uses a pattern derived from the current file's extension."
  :type '(repeat string))

(defcustom grep-o-matic-ask-about-save t
  "If non-nil, ask which buffers to save before searching.
Otherwise, all modified buffers are saved without asking."
  :type 'boolean)

(defcustom grep-o-matic-use-git-grep nil
  "If non-nil, use `git grep' in git repositories instead of rgrep."
  :type 'boolean)

(defcustom grep-o-matic-git-grep-template "git grep <C> -n -e <R> -- <F>"
  "Template for git grep command.
See `grep-template' for the meaning of <C>, <R>, <F> placeholders."
  :type 'string)

(defun grep-o-matic--get-regexp (prompt)
  "Return the search regexp.
If PROMPT is non-nil, query the user (with word-at-point as default).
Otherwise, use `grep-tag-default' and add it to history."
  (let ((regexp (grep-tag-default)))
    (if (and (not prompt) regexp)
        (progn
          (add-to-list 'grep-regexp-history regexp)
          regexp)
      (grep-read-regexp))))

(defun grep-o-matic--project-root ()
  "Return the project/repository root for the current buffer.
Tries `project-root', `vc-root-dir', then falls back to `default-directory'."
  (or (and (fboundp 'project-root)
           (when-let ((proj (project-current)))
             (project-root proj)))
      (vc-root-dir)
      default-directory))

(defun grep-o-matic--search-patterns ()
  "Compute file glob patterns for the search.
If the current file matches one of `grep-o-matic-search-patterns', use all
of them.  Otherwise, derive a pattern from the current file's extension."
  (let* ((filename (and buffer-file-name
                       (file-name-nondirectory buffer-file-name)))
         (extension (and buffer-file-name
                        (file-name-extension buffer-file-name)))
         (patterns grep-o-matic-search-patterns)
         (matches (when filename
                    (cl-some (lambda (pat)
                               (string-match-p (wildcard-to-regexp pat) filename))
                             patterns))))
    (if matches
        (mapconcat #'identity patterns " ")
      (if extension
          (concat "*." extension)
        "*"))))

(defun grep-o-matic--search-directory (prompt directory)
  "Search DIRECTORY recursively.  With PROMPT non-nil, ask for the regexp."
  (let ((patterns (grep-o-matic--search-patterns)))
    (grep-compute-defaults)
    (save-some-buffers (not grep-o-matic-ask-about-save) nil)
    (rgrep (grep-o-matic--get-regexp prompt)
           patterns
           (or directory default-directory))))

;;;###autoload
(defun grep-o-matic-repository (&optional prompt)
  "Search the project root for word at point.
With \\[universal-argument], prompt for the search regexp."
  (interactive "P")
  (let ((root (grep-o-matic--project-root)))
    (if (and grep-o-matic-use-git-grep
             buffer-file-name
             (let ((backend (vc-backend buffer-file-name)))
               (and backend
                    (string-equal "git" (downcase (symbol-name backend))))))
        ;; git grep path
        (let ((regexp (grep-o-matic--get-regexp prompt))
              (patterns (grep-o-matic--search-patterns)))
          (grep-compute-defaults)
          (save-some-buffers (not grep-o-matic-ask-about-save) nil)
          (let ((default-directory root))
            (grep (grep-expand-template
                   (concat (grep-expand-template
                            grep-o-matic-git-grep-template
                            regexp
                            patterns)
                           " | cat")))))
      ;; rgrep path
      (grep-o-matic--search-directory prompt root))))

;;;###autoload
(defun grep-o-matic-current-directory (&optional prompt)
  "Search current directory for word at point.
With \\[universal-argument], prompt for the search regexp."
  (interactive "P")
  (grep-o-matic--search-directory
   prompt
   (and buffer-file-name (file-name-directory buffer-file-name))))

;;;###autoload
(defun grep-o-matic-visited-files (&optional prompt)
  "Search all currently visited file buffers for word at point.
With \\[universal-argument], prompt for the search regexp."
  (interactive "P")
  (let* ((regexp (grep-o-matic--get-regexp prompt))
         (files (cl-loop for buf in (buffer-list)
                         for file = (buffer-file-name buf)
                         when (and file (not (file-remote-p file)))
                         collect file))
         (file-args (mapconcat #'shell-quote-argument files " ")))
    (unless files
      (user-error "No file-visiting buffers"))
    (grep-compute-defaults)
    (save-some-buffers (not grep-o-matic-ask-about-save) nil)
    (grep (grep-expand-template grep-template regexp file-args "" ""))))

;;;###autoload
(defun grep-o-matic-setup-keys ()
  "Set up default key bindings for grep-o-matic.
Binds M-] as a prefix: M-/ or / for repo, M-. or . for directory,
M-, or , for visited files."
  (define-prefix-command 'grep-o-matic-map)
  (define-key grep-o-matic-map (kbd "M-/") #'grep-o-matic-repository)
  (define-key grep-o-matic-map (kbd "/")   #'grep-o-matic-repository)
  (define-key grep-o-matic-map (kbd "M-.") #'grep-o-matic-current-directory)
  (define-key grep-o-matic-map (kbd ".")   #'grep-o-matic-current-directory)
  (define-key grep-o-matic-map (kbd "M-,") #'grep-o-matic-visited-files)
  (define-key grep-o-matic-map (kbd ",")   #'grep-o-matic-visited-files)
  (global-set-key (kbd "M-]") 'grep-o-matic-map))

(provide 'grep-o-matic)

;;; grep-o-matic.el ends here
