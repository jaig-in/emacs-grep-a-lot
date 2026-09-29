;;; grep-a-lot.el --- Multiple named grep buffers with ring navigation  -*- lexical-binding: t; -*-

;; Copyright (C) 2008-2021 Avi Rozen
;; Copyright (C) 2026 Jai G (modernized rewrite)

;; Author: Jai G
;; Original-Author: Avi Rozen <avi.rozen@gmail.com>
;; URL: https://github.com/jaig-in/emacs-grep-a-lot
;; Version: 2.0.0
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

;; A modernized rewrite of the original grep-a-lot 1.0.7 by Avi Rozen
;; (https://github.com/ZungBang/emacs-grep-a-lot).
;;
;; Every `grep', `lgrep', and `rgrep' invocation gets its own buffer
;; named *grep:<search-term>*<N> instead of reusing *grep*.
;; Navigate the grep buffer ring with simple key bindings.
;;
;; Part of the grep-a-lot suite:
;;   grep-a-lot   — multiple named search buffers + ring navigation (this file)
;;   grep-o-matic — word-at-point grep via rgrep
;;   rg-o-matic   — word-at-point search via ripgrep
;;
;; Usage:
;;   (require 'grep-a-lot)
;;   (grep-a-lot-setup-keys)   ; optional — binds M-g ] / [ / _
;;
;; Any buffer in `grep-mode' (including `compilation-start' with
;; 'grep-mode) participates in the ring.  This means buffers created
;; by rg-o-matic or any other package that uses grep-mode are navigable
;; with the same keys.
;;
;; Changes from the original 1.x:
;; - Uses `advice-add' / `compilation-start-hook', no deprecated `defadvice'.
;; - Buffers are named after the search term, not just numbered.
;; - Dropped igrep support (unmaintained since 2013).
;; - Requires Emacs 28.1+ (lexical binding, cl-lib builtins).

;;; Code:

(require 'grep)
(require 'cl-lib)

(defgroup grep-a-lot nil
  "Multiple named grep buffers with ring navigation."
  :group 'grep
  :prefix "grep-a-lot-")

(defvar grep-a-lot--counter 0
  "Monotonically increasing counter for unique grep buffer numbering.")

(defun grep-a-lot--extract-term (cmd-str)
  "Extract the search term from a grep command string CMD-STR."
  (cond
   ;; -e TERM or --regexp=TERM
   ((string-match "\\(?:-e\\|--regexp[= ]\\)\\s-*['\"]?\\([^'\" \t\n]+\\)" cmd-str)
    (match-string 1 cmd-str))
   ;; grep ... 'TERM' or "TERM"
   ((string-match "grep.*?['\"]\\([^'\"]+\\)['\"]" cmd-str)
    (match-string 1 cmd-str))
   (t "?")))

(defun grep-a-lot--sanitize-name (term)
  "Return a filesystem/buffer-safe version of TERM, max 40 chars."
  (replace-regexp-in-string
   "[^[:alnum:]._-]" "_"
   (substring term 0 (min (length term) 40))))

(defun grep-a-lot--rename-buffer ()
  "Rename the current grep buffer to *grep:<search-term>*<N>."
  (when (and (derived-mode-p 'grep-mode)
             (string-match-p "^\\*grep\\*" (buffer-name)))
    (let* ((cmd (or (bound-and-true-p compilation-arguments)
                    (and (local-variable-p 'compile-command) compile-command)
                    ""))
           (cmd-str (if (listp cmd) (car cmd) cmd))
           (term (grep-a-lot--extract-term cmd-str))
           (clean (grep-a-lot--sanitize-name term))
           (n (cl-incf grep-a-lot--counter))
           (new-name (format "*grep:%s*<%d>" clean n)))
      (rename-buffer new-name t))))

(defun grep-a-lot--on-compilation-start (_proc)
  "Hook to rename grep buffers after compilation starts."
  (when (derived-mode-p 'grep-mode)
    (run-at-time 0 nil #'grep-a-lot--rename-buffer)))

(add-hook 'compilation-start-hook #'grep-a-lot--on-compilation-start)

;;;###autoload
(defun grep-a-lot-buffers ()
  "Return all `grep-mode' buffers sorted by buffer name."
  (sort (cl-remove-if-not
         (lambda (b) (with-current-buffer b (derived-mode-p 'grep-mode)))
         (buffer-list))
        (lambda (a b) (string< (buffer-name a) (buffer-name b)))))

(defun grep-a-lot--cycle (direction)
  "Switch to the next (DIRECTION=1) or previous (DIRECTION=-1) grep buffer."
  (let* ((bufs (grep-a-lot-buffers))
         (len (length bufs))
         (cur (current-buffer))
         (idx (cl-position cur bufs)))
    (when (and bufs (> len 0))
      (let ((target (if idx
                       (nth (mod (+ idx direction) len) bufs)
                     (car bufs))))
        (switch-to-buffer target)
        (message "grep %d/%d: %s"
                 (1+ (cl-position target bufs)) len (buffer-name target))))))

;;;###autoload
(defun grep-a-lot-next ()
  "Switch to the next grep/rg buffer in the ring."
  (interactive)
  (grep-a-lot--cycle 1))

;;;###autoload
(defun grep-a-lot-prev ()
  "Switch to the previous grep/rg buffer in the ring."
  (interactive)
  (grep-a-lot--cycle -1))

;;;###autoload
(defun grep-a-lot-kill-all ()
  "Kill all grep/rg buffers."
  (interactive)
  (let ((bufs (grep-a-lot-buffers)))
    (mapc #'kill-buffer bufs)
    (message "Killed %d grep buffer(s)." (length bufs))))

;;;###autoload
(defun grep-a-lot-setup-keys ()
  "Set up default key bindings for grep-a-lot navigation."
  (global-set-key (kbd "M-g ]") #'grep-a-lot-next)
  (global-set-key (kbd "M-g [") #'grep-a-lot-prev)
  (global-set-key (kbd "M-g _") #'grep-a-lot-kill-all))

(provide 'grep-a-lot)

;;; grep-a-lot.el ends here
