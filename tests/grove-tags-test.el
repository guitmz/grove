;;; grove-tags-test.el --- Tag handling tests for grove -*- lexical-binding: t -*-

;; Copyright 2026 Guilherme Thomazi Bonicontro

;;; Commentary:

;; Tests covering tag parsing and search pattern construction.

;;; Code:

(require 'ert)
(require 'grove-core)
(require 'grove-search)

(ert-deftest grove-parse-note-collects-inline-hashtags ()
  (let ((file (make-temp-file "grove-tags" nil ".org"
                              "#+title: Tag test\n\nBody with #alpha and #beta.\n")))
    (unwind-protect
        (should (equal (plist-get (grove--parse-note file) :tags)
                       '("alpha" "beta")))
      (delete-file file))))

(ert-deftest grove-parse-note-merges-filetags-and-inline-hashtags ()
  (let ((file (make-temp-file "grove-tags" nil ".org"
                              "#+title: Tag test\n#+filetags: :alpha:beta:\n\nBody with #beta and #gamma.\n")))
    (unwind-protect
        (should (equal (plist-get (grove--parse-note file) :tags)
                       '("alpha" "beta" "gamma")))
      (delete-file file))))

(ert-deftest grove-search-tag-normalizes-documented-input-forms ()
  (should (equal (grove-search--normalize-tag "work") "work"))
  (should (equal (grove-search--normalize-tag "#work") "work"))
  (should (equal (grove-search--normalize-tag ":work:") "work"))
  (should (equal (grove-search--normalize-tag "  #work  ") "work")))

(ert-deftest grove-search-tag-pattern-escapes-regexp-characters ()
  (should (equal (grove-search--tag-pattern "#a+b?")
                 "(#a\\+b\\?\\b|:a\\+b\\?:)")))

(provide 'grove-tags-test)
;;; grove-tags-test.el ends here
