;;; package --- Summary
;;; export.el --- Export Org Mode files to HTML
;;; Copyright (C) 2022  Reed Spool
;;; -*- lexical-binding: t; -*-
;;;
;;; Commentary:
;;;   Export Org Mode files to HTML
;;;
;;; Code:
(require 'ox-publish)
;; Need to add to the load path the location of this script where ox-11ty.el is defined
(add-to-list 'load-path "./")
(require 'ox-11ty "./ox-11ty.el")

(defun org-11ty-publish-to-11ty (plist filename pub-dir)
  "Publish an org file to 11ty.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

Return output file name."
  (org-publish-org-to
   '11ty filename
   (concat (when (> (length org-html-extension) 0) ".")
           (or (plist-get plist :html-extension)
               org-html-extension
               "html"))
   plist pub-dir))


(defun buffer-string* (buffer)
  "Get contents of BUFFER as a string. From https://emacs.stackexchange.com/a/697."
  (with-current-buffer buffer
    (buffer-string)))

;;
;; Note: Stole trim functions from s.el, see https://github.com/magnars/s.el#functions
;;
(defun s-trim-left (s)
  "Remove whitespace at the beginning of S."
  (declare (pure t) (side-effect-free t))
  (save-match-data
    (if (string-match "\\`[ \t\n\r]+" s)
        (replace-match "" t t s)
      s)))

(defun s-trim-right (s)
  "Remove whitespace at the end of S."
  (save-match-data
    (declare (pure t) (side-effect-free t))
    (if (string-match "[ \t\n\r]+\\'" s)
        (replace-match "" t t s)
      s)))

(defun s-trim (s)
  "Remove whitespace at the beginning and end of S."
  (declare (pure t) (side-effect-free t))
  (s-trim-left (s-trim-right s)))

;; Retrieve the output directory passed from shell
;; (defvar output-directory (nth 3 command-line-args))
(defvar output-directory "~/org/www")

(let*
    (
     (published-tag ":blog_published:")
     (grep-buffer-name "*GREP*")
     ;; Must end in a slash to be recognized as a directory by copy-file
     (tmp-directory "~/org/roam-publish-temp/")
     (base-directory tmp-directory)
     (notes-directory "~/org/roam")
     (grep-cmd (format "grep -lr %s %s" published-tag (expand-file-name notes-directory)))
     )
  (message "Export base directory: %s" base-directory)
  (message "Export output directory: %s" output-directory)
  (message "Full grep command: %s" grep-cmd)

  ;; Grep for a list of file names with the published tag
  ;; Not sure why this prints the output to stdout when run from export.sh
  ;; TODO Try changing from shell-command to see if other options are silent
  ;;      See https://stackoverflow.com/a/1455557
  (defvar grep-process
    (make-process
     :name "export-org-mode-grep"
     :buffer (get-buffer-create grep-buffer-name)
     :command (split-string grep-cmd " ")
     :stderr "*GREP ERROR*"))

  ;; Busy-wait loop until this process is complete
  (while (process-live-p grep-process)
    (sleep-for 0.1))

  (if (not (eq (process-exit-status grep-process) 0))
      (progn
        (message "Grep exited with status %s, halting" (process-exit-status grep-process))
        (kill-emacs 1)))

  (defvar grep-results (s-trim (buffer-string* grep-buffer-name)))

  ;; Extract the results of the search from buffer to list of strings
  ;; NOTE: Remove last 2 items because make-process prints "\nProcess exited"
  (defvar files-to-publish
    (butlast (split-string grep-results "\n") 2))

  ;; Take only the file names from each full path from grep output
  (defvar filenames-to-publish
    (mapcar
     'file-name-nondirectory
     files-to-publish))

  (message "Publishing %d files:\n%s" (length filenames-to-publish) (mapconcat 'identity filenames-to-publish "\n"))

  (delete-directory tmp-directory :recursive)
  (make-directory tmp-directory :parents)
  (mapc
   (lambda (file) (copy-file file tmp-directory :ok-if-already-exists))
   files-to-publish)

  (setq org-export-with-broken-links t)
  (setq org-publish-project-alist
        `(
          ;; TODO: Would like to be inserting these 3 into the alist instead of wiping out the alist, in case in the future i want to do other projects elsewhere
          ("blog" :components ("blog-notes"))

          ("blog-notes"
           :body-only t
           :base-directory ,base-directory
           :base-extension "org"
           :publishing-directory ,output-directory
           :recursive t
           :publishing-function org-11ty-publish-to-11ty
           :headline-levels 4           ; Just the default for this project.
           :auto-sitemap nil
           :sitemap-title "Site Index"
           :sitemap-filename "sitemap.org"
           ;; :sitemap-style "tree"
           :author "Reed Spool"
           :email "reedwith2es@gmail.com"
           :section-numbers nil
           :with-toc nil
           :with-author nil
           :with-creator nil
           :with-email nil
           ;; :select-tags nil ;; nil to prevent accidental default behavior if I start using tags
           :select-tags ("blog_published") ;; Only org sub-trees with these tags will be published
           :exclude-tags ("noexport") ;; Exclude any sub-tree with these tags. Occurs before include
           :with-date nil
           :time-stamp-file t ;; default t
           :with-tags nil ;; Just get rid of the tag itself, export the rest of the headline
           :with-title nil

           ;; HTML specific options
           :html-head-extra nil ;; We're doing body-only so no use for head
           ;; :htmlized-source t ;; testing: what does this do?
           :html-checkbox-type "ascii" ;; might try "html" as well
           :html-container "article" ;; testing out, default is "div", non-default prevents org-info.js
           :html-doctype "html5"     ;; I think this will work to set to html5??
           :html-head "" ;; This is the default, but apparently this allows to completely overwrite head. I think head-extra is rly meant to add on a per-file basis
           :html-head-include-default-style nil ;; Check out ‘org-html-style-default’ for what would be here if this was non-nil
           :html-head-include-scripts nil ;; Ditto above with   ‘org-html-scripts’
           :html-home/up-format nil ;; Auto "home" and "up" links, like emacs info. No thanks
           :html-html5-fancy t ;; Supposedly use HTML5 stuff. Not sure what this does
           :html-indent t ;; Prettify generated html. May screw up generated code blocks
           :html-use-infojs nil     ;; Much easier
           :html-inline-image-rules ;; So far, the default, but might want to play
           (("file" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'")
            ("attachment" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'")
            ("http" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'")
            ("https" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'"))
           :html-inline-images t ;; Default, nil means <a href> instead of <img>
           :html-mathjax-options nil  ;; Hoping nil disables mathjax
           :html-mathjax-template nil ;; ditto above
           :html-metadata-timestamp-format "%A %B %e, %Y at %H:%M %Z" ;; See ‘format-time-string’. Default was "%Y-%m-%d %a %H:%M"
           :html-preamble nil
           :html-preamble-format nil ;; preamble unused with :body-only
           :html-postamble nil
           :html-postamble-format nil ;; No post-amble, unused with :body-only
           :html-self-link-headlines nil ;; Trying this out, default nil
           :html-text-markup-alist ;; Default so far, want to change to html5
           ((bold . "<strong>%s</strong>")
            (code . "<code>%s</code>")
            (italic . "<em>%s</em>")
            (strike-through . "<del>%s</del>")
            (underline . "<span class=\"underline\">%s</span>")
            (verbatim . "<code>%s</code>"))
           :html-tag-class-prefix "tag-"       ;; Unsure if i'll ever use this
           :html-todo-kwd-class-prefix "todo-" ;; Ditto above
           :html-toplevel-hlevel 2 ;; NOTE: Effects corresponding classes like outline-1.  2 is default, consider bumping to 1 if we get rid of the #+Title.
           :html-validation-link nil ;; Wonder if this will disable validation link?
           :html-viewport nil        ;; Unused with :body-only
           )
          )))
;; (org-publish-project "blog") ;; Actually perform the pubilsh
(org-publish-project "blog" t) ;; Dump cache and republish all

;; Author: Reed Spool <reedwith2es@gmail.com>
(provide 'export)
;;; export.el ends here
