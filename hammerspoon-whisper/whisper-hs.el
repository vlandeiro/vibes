;;; whisper-hs.el --- Hammerspoon Whisper integration for Emacs  -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides marker-based text insertion for the hammerspoon-whisper dictation tool.
;;
;; Install via Doom Emacs packages.el:
;;
;;   (package! whisper-hs
;;     :recipe (:host github
;;              :repo "vlandeiro/vibes"
;;              :files ("hammerspoon-whisper/whisper-hs.el")))
;;
;; Then in config.el:
;;
;;   (use-package! whisper-hs)
;;
;; Without this package, hammerspoon-whisper falls back to keyboard emulation.

;;; Code:

(defvar whisper-hs--marker nil
  "Marker for whisper text insertion point.")

(defun whisper-create-marker ()
  "Create a marker at point in the currently selected window's buffer."
  (with-current-buffer (window-buffer (selected-window))
    (setq whisper-hs--marker (copy-marker (point) t))))

(defun whisper-insert (text)
  "Insert TEXT at the whisper marker position.
In `vterm-mode' buffers, uses `vterm-send-string' instead."
  (when (and (markerp whisper-hs--marker) (marker-buffer whisper-hs--marker))
    (with-current-buffer (marker-buffer whisper-hs--marker)
      (if (derived-mode-p 'vterm-mode)
          (vterm-send-string text)
        (goto-char whisper-hs--marker)
        (insert text)))))

(defun whisper-cleanup ()
  "Release the whisper marker."
  (when (markerp whisper-hs--marker)
    (set-marker whisper-hs--marker nil)
    (setq whisper-hs--marker nil)))

(provide 'whisper-hs)
;;; whisper-hs.el ends here
