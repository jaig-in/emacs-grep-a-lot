;;; rg-o-matic.el --- Ripgrep word-at-point in repo, directory, or open files  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jai G

;; Author: Jai G
;; URL: https://github.com/jaig-in/emacs-grep-a-lot
;; Version: 1.0.0
;; Keywords: tools, convenience, search
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

;; The ripgrep counterpart to grep-o-matic.  One key to search for the
;; word under the cursor using `rg' (ripgrep):
;;
;;   `rg-o-matic-project'   — in the project/repo root
;;   `rg-o-matic-directory' — in the current directory, recursively
;;   `rg-o-matic-open-files' — across all visited file buffers
;;
;; With C-u prefix, prompts for the search term instead.
;;
;; Results land in uniquely named *rg:<term>*<N> buffers using
;; `grep-mode', so `next-error', `compile-goto-error', and grep-a-lot
;; ring navigation all work out of the box.
;;
;; Part of the grep-a-lot suite:
;;   grep-a-lot   — multiple named search buffers + ring navigation
;;   grep-o-matic — word-at-point grep via rgrep
;;   rg-o-matic   — word-at-point search via ripgrep (this file)
;;
;; Usage:
;;   (require 'rg-o-matic)
;;   (rg-o-matic-setup-keys)   ; optional — binds M-\ prefix
;;
;; Requires `rg' (ripgrep) on PATH.

;;; Code:

(require 'cl-lib)

(defgroup rg-o-matic nil
  "Ripgrep word-at-point in repo, directory, or open files."
  :group 'grep
  :prefix "rg-o-matic-")

(defcustom rg-o-matic-executable "rg"
  "Path to the ripgrep executable."
  :type 'string)

(defcustom rg-o-matic-default-args "--color=always --no-heading --line-number --smart-case"
  "Default arguments passed to rg on every invocation."
  :type 'string)

(defvar rg-o-matic--counter 0
  "Counter for unique rg buffer numbering.")

(defun rg-o-matic--sanitize-name (term)
  "Return a buffer-safe version of TERM, max 40 chars."
  (replace-regexp-in-string
   "[^[:alnum:]._-]" "_"
   (substring term 0 (min (length term) 40))))

(defun rg-o-matic--read-term (prompt)
  "Read a search term: symbol-at-point if non-nil, else PROMPT."
  (if prompt
      (read-string "rg search: " (thing-at-point 'symbol t))
    (or (thing-at-point 'symbol t)
        (read-string "rg search: "))))

;;;###autoload
(defun rg-o-matic-search (term directory &optional extra-args)
  "Run ripgrep for TERM in DIRECTORY.
Results go to a uniquely named *rg:<term>*<N> buffer in `grep-mode'.
EXTRA-ARGS are appended to the rg command line."
  (let* ((clean (rg-o-matic--sanitize-name term))
         (n (cl-incf rg-o-matic--counter))
         (buf-name (format "*rg:%s*<%d>" clean n))
         (args (or extra-args ""))
         (cmd (format "%s %s %s -- %s %s"
                      rg-o-matic-executable
                      rg-o-matic-default-args
                      args
                      (shell-quote-argument term)
                      (shell-quote-argument (expand-file-name directory)))))
    (compilation-start cmd 'grep-mode (lambda (_) buf-name))))

;;;###autoload
(defun rg-o-matic-project (&optional prompt)
  "Ripgrep word-at-point (or prompted with \\[universal-argument]) in the project root.
Falls back to `vc-root-dir', then `default-directory'."
  (interactive "P")
  (let* ((term (rg-o-matic--read-term prompt))
         (root (or (and (fboundp 'project-root)
                        (when-let ((proj (project-current)))
                          (project-root proj)))
                   (vc-root-dir)
                   default-directory)))
    (rg-o-matic-search term root)))

;;;###autoload
(defun rg-o-matic-directory (&optional prompt)
  "Ripgrep word-at-point (or prompted with \\[universal-argument]) in `default-directory'."
  (interactive "P")
  (let ((term (rg-o-matic--read-term prompt)))
    (rg-o-matic-search term default-directory)))

;;;###autoload
(defun rg-o-matic-open-files (&optional prompt)
  "Ripgrep word-at-point across all currently visited file buffers."
  (interactive "P")
  (let* ((term (rg-o-matic--read-term prompt))
         (files (cl-remove-if-not #'identity
                                  (mapcar #'buffer-file-name (buffer-list)))))
    (unless files
      (user-error "No file-visiting buffers"))
    (let* ((clean (rg-o-matic--sanitize-name term))
           (n (cl-incf rg-o-matic--counter))
           (buf-name (format "*rg:%s*<%d>" clean n))
           (file-args (mapconcat #'shell-quote-argument files " "))
           (cmd (format "%s %s -- %s %s"
                        rg-o-matic-executable
                        rg-o-matic-default-args
                        (shell-quote-argument term) file-args)))
      (compilation-start cmd 'grep-mode (lambda (_) buf-name)))))

;;;###autoload
(defun rg-o-matic-setup-keys ()
  "Set up default key bindings for rg-o-matic.
Binds M-\\ as a prefix with / . , for project, directory, open files."
  (define-prefix-command 'rg-o-matic-map)
  (define-key rg-o-matic-map (kbd "/") #'rg-o-matic-project)
  (define-key rg-o-matic-map (kbd ".") #'rg-o-matic-directory)
  (define-key rg-o-matic-map (kbd ",") #'rg-o-matic-open-files)
  (global-set-key (kbd "M-\\") 'rg-o-matic-map))

(provide 'rg-o-matic)

;;; rg-o-matic.el ends here
