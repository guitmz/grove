;;; grove-review-test.el --- Regression tests for review findings -*- lexical-binding: t -*-

;; Copyright 2026 Guilherme Thomazi Bonicontro

;;; Commentary:

;; Regression coverage for issues found during code review.

;;; Code:

(require 'ert)
(require 'grove-core)
(require 'grove-link)
(require 'grove-inbox)
(require 'grove-tree)
(require 'subr-x)

(ert-deftest grove-parse-note-reads-beyond-4kb ()
  (let ((file (make-temp-file "grove-large" nil ".org"
                              (concat "#+title: Large note\n\n"
                                      (make-string 5000 ?a)
                                      "\n#late-tag\n[[Late Link]]\n"))))
    (unwind-protect
        (let ((meta (grove--parse-note file)))
          (should (equal (plist-get meta :tags) '("late-tag")))
          (should (equal (plist-get meta :links) '("Late Link"))))
      (delete-file file))))

(ert-deftest grove-link-follow-creates-unique-file-on-filename-collision ()
  (let* ((grove-directory (make-temp-file "grove-vault" t))
         (existing (expand-file-name "foo.org" grove-directory)))
    (unwind-protect
        (progn
          (with-temp-file existing
            (insert "#+title: Existing\n\n"))
          (cl-letf (((symbol-function 'grove-link--resolve) (lambda (_title) nil))
                    ((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
            (grove-link-follow "Foo!")
            (should (buffer-file-name))
            (should (string= (file-name-nondirectory (buffer-file-name)) "foo-1.org"))
            (should (string= (buffer-string) "#+title: Foo!\n\n")))
          (when (buffer-live-p (current-buffer))
            (kill-buffer (current-buffer)))
          (with-temp-buffer
            (insert-file-contents existing)
            (should (string= (buffer-string) "#+title: Existing\n\n"))))
      (delete-directory grove-directory t))))

(ert-deftest grove-inbox-review-renders-unlinked-section ()
  (let ((grove-directory (make-temp-file "grove-vault" t)))
    (unwind-protect
        (let ((grove--cache (make-hash-table :test #'equal)))
          (puthash "/tmp/a.org" (list :title "A" :tags nil) grove--cache)
          (puthash "/tmp/b.org" (list :title "B" :tags '("tag")) grove--cache)
          (cl-letf (((symbol-function 'grove--refresh-cache) #'ignore)
                    ((symbol-function 'grove--ensure-directory) #'ignore)
                    ((symbol-function 'grove-inbox--unlinked-notes)
                     (lambda () '(("B" . "/tmp/b.org")))))
            (grove-inbox-review)
            (with-current-buffer grove-inbox-buffer-name
              (should (string-match-p "No backlinks (1)" (buffer-string)))
              (should (string-match-p "B" (buffer-string))))
            (kill-buffer grove-inbox-buffer-name)))
      (delete-directory grove-directory t))))

(ert-deftest grove-tree-refresh-rebuilds-expanded-children ()
  (let* ((grove-directory (make-temp-file "grove-vault" t))
         (subdir (expand-file-name "sub" grove-directory))
         (file (expand-file-name "note.org" subdir)))
    (unwind-protect
        (progn
          (make-directory subdir)
          (with-temp-file file
            (insert "#+title: Note\n"))
          (with-current-buffer (get-buffer-create grove-tree-buffer-name)
            (grove-tree-mode)
            (clrhash grove-tree--expanded)
            (puthash subdir t grove-tree--expanded)
            (grove-tree-refresh)
            (let ((items nil))
              (ewoc-map (lambda (node) (push (grove-tree-node-name node) items))
                        grove-tree--ewoc)
              (should (member "sub" items))
              (should (member "note" items))))
          (kill-buffer grove-tree-buffer-name))
      (delete-directory grove-directory t))))

(provide 'grove-review-test)
;;; grove-review-test.el ends here
