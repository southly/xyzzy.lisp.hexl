;;; hexl.el --- edit a file in a hex dump format using the hexl filter

;; Copyright (C) 1989, 1994, 1998, 2001 Free Software Foundation, Inc.

;; Author: Keith Gabryelski <ag@wheaties.ai.mit.edu>
;; Maintainer: FSF
;; Keywords: data

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This package implements a major mode for editing binary files.  It uses
;; a program called hexl, supplied with the GNU Emacs distribution, that
;; can filter a binary into an editable format or from the format back into
;; binary.  For full instructions, invoke `hexl-mode' on an empty buffer and
;; do `M-x describe-mode'.
;;
;; This may be useful in your .emacs:
;;
;;	(autoload 'hexl-find-file "hexl"
;;	  "Edit file FILENAME in hexl-mode." t)
;;	
;;	(define-key global-map "\C-c\C-h" 'hexl-find-file)
;;
;; NOTE: Remember to change HEXL-PROGRAM or HEXL-OPTIONS if needed.
;;
;; Currently hexl only supports big endian hex output with 16 bit
;; grouping.
;;
;; -iso in `hexl-options' will allow iso characters to display in the
;; ASCII region of the screen (if your emacs supports this) instead of
;; changing them to dots.

;;; Code:

;;
;; vars here
;;

(defvar hexl-program (merge-pathnames "etc/hexl" (si:system-root))
  "The program that will hexlify and dehexlify its stdin.
`hexl-program' will always be concatenated with `hexl-options'
and \"-de\" when dehexlifying a buffer."
  )

(defvar hexl-iso ""
  "If your emacs can handle ISO characters, this should be set to
\"-iso\" otherwise it should be \"\"."
  )

(defvar hexl-options (format nil "-hex ~A" hexl-iso)
  "Options to hexl-program that suit your needs."
  )

(defvar hexlify-command
  (format nil "~A ~A"
          hexl-program
          hexl-options)
  "The command to use to hexlify a buffer."
  )

(defvar dehexlify-command
  (format nil "~A -de ~A"
          hexl-program
          hexl-options)
  "The command to use to unhexlify a buffer."
  )

(defvar hexl-follow-ascii t
  "If non-nil then highlight the ASCII character corresponding to point."
  )

(defvar hexl-mode-hook nil)

(defvar hexl-mode-map nil)

;;;###autoload
(defun hexl-mode ()
  "\\<hexl-mode-map>A mode for editing binary files in hex dump format.
This is not an ordinary major mode; it alters some aspects
of the current mode's behavior, but not all; also, you can exit
Hexl mode and return to the previous mode using `hexl-mode-exit'.

This function automatically converts a buffer into the hexl format
using the function `hexlify-buffer'.

Each line in the buffer has an \"address\" (displayed in hexadecimal)
representing the offset into the file that the characters on this line
are at and 16 characters from the file (displayed as hexadecimal
values grouped every 16 bits) and as their ASCII values.

If any of the characters (displayed as ASCII characters) are
unprintable (control or meta characters) they will be replaced as
periods.

If `hexl-mode' is invoked with an argument the buffer is assumed to be
in hexl format.

A sample format:

  HEX ADDR: 0001 0203 0405 0607 0809 0a0b 0c0d 0e0f     ASCII-TEXT
  --------  ---- ---- ---- ---- ---- ---- ---- ----  ----------------
  00000000: 5468 6973 2069 7320 6865 786c 2d6d 6f64  This is hexl-mod
  00000010: 652e 2020 4561 6368 206c 696e 6520 7265  e.  Each line re
  00000020: 7072 6573 656e 7473 2031 3620 6279 7465  presents 16 byte
  00000030: 7320 6173 2068 6578 6164 6563 696d 616c  s as hexadecimal
  00000040: 2041 5343 4949 0a61 6e64 2070 7269 6e74   ASCII.and print
  00000050: 6162 6c65 2041 5343 4949 2063 6861 7261  able ASCII chara
  00000060: 6374 6572 732e 2020 416e 7920 636f 6e74  cters.  Any cont
  00000070: 726f 6c20 6f72 206e 6f6e 2d41 5343 4949  rol or non-ASCII
  00000080: 2063 6861 7261 6374 6572 730a 6172 6520   characters.are 
  00000090: 6469 7370 6c61 7965 6420 6173 2070 6572  displayed as per
  000000a0: 696f 6473 2069 6e20 7468 6520 7072 696e  iods in the prin
  000000b0: 7461 626c 6520 6368 6172 6163 7465 7220  table character 
  000000c0: 7265 6769 6f6e 2e0a                      region..

Movement is as simple as movement in a normal emacs text buffer.  Most
cursor movement bindings are the same (ie. Use \\[hexl-backward-char], \\[hexl-forward-char], \\[hexl-next-line], and \\[hexl-previous-line]
to move the cursor left, right, down, and up).

Advanced cursor movement commands (ala \\[hexl-beginning-of-line], \\[hexl-end-of-line], \\[hexl-beginning-of-buffer], and \\[hexl-end-of-buffer]) are
also supported.

There are several ways to change text in hexl mode:

ASCII characters (character between space (0x20) and tilde (0x7E)) are
bound to self-insert so you can simply type the character and it will
insert itself (actually overstrike) into the buffer.

\\[hexl-quoted-insert] followed by another keystroke allows you to insert the key even if
it isn't bound to self-insert.  An octal number can be supplied in place
of another key to insert the octal number's ASCII representation.

\\[hexl-insert-hex-char] will insert a given hexadecimal value (if it is between 0 and 0xFF)
into the buffer at the current point.

\\[hexl-insert-octal-char] will insert a given octal value (if it is between 0 and 0377)
into the buffer at the current point.

\\[hexl-insert-decimal-char] will insert a given decimal value (if it is between 0 and 255)
into the buffer at the current point.

\\[hexl-mode-exit] will exit hexl-mode.

Note: saving the file with any of the usual Emacs commands
will actually convert it back to binary format while saving.

You can use \\[hexl-find-file] to visit a file in Hexl mode.

\\[describe-bindings] for advanced commands."
  (interactive)
  (unless (eq buffer-mode 'hexl-mode)
    (let ((mode buffer-mode))
      (kill-all-local-variables)
      (let ((buffer-read-only nil))
        (declare (special buffer-read-only))

        (setq buffer-mode 'hexl-mode)
        (setq mode-name "Hexl")
        (use-keymap hexl-mode-map)
        (use-syntax-table ed::*fundamental-mode-syntax-table*)
        (make-local-variable 'hexl-max-address)
        (setq hexl-max-address (1- (file-length (get-buffer-file-name))))
        (hexlify-buffer)

        (make-local-variable 'hexl-mode-old-major-mode)
        (setq hexl-mode-old-major-mode mode)
        (make-local-variable 'hexl-ascii-overlay)
        (setq hexl-ascii-overlay nil)
        (make-local-variable 'auto-save)
        (setq auto-save nil)
        (if hexl-follow-ascii (hexl-follow-ascii t)))))
  (run-hooks 'hexl-mode-hook))

(defun hexl-save-buffer ()
  "Save a hexl format buffer as binary in visited file if modified."
  (interactive)
  (if (buffer-modified-p)
      (progn
        (save-excursion
          (let ((buf (selected-buffer))
                (file (get-buffer-file-name))
                (tmp (get-buffer-create " HEXL")))
            (set-buffer tmp)
            (erase-buffer tmp)
            (setup-temp-buffer tmp)
            (insert-buffer buf)
            (dehexlify-buffer-to-file file)))
        (update-visited-file-modtime)
        (set-buffer-modified-p nil))
    (message "(No changes need to be saved)")))

(defun dehexlify-buffer-to-file (file)
  (let ((infile (make-temp-file-name)))
    (write-region 0 (buffer-size) infile)
    (unwind-protect
        (multiple-value-bind (cmdline dir)
            (ed::shell-command-line dehexlify-command (default-directory))
          (call-process cmdline
                        :input infile
                        :output file
                        :exec-directory dir
                        :show :minimize
                        :wait t))
      (when infile
        (delete-file infile)))))

;; ;;;###autoload
(defun hexl-find-file (filename)
  "Edit file FILENAME in hexl-mode.
Switch to a buffer visiting file FILENAME, creating one in none exists."
  (interactive "fFilename: ")
  (let ((*expected-fileio-encoding* *encoding-binary*)
        (*expected-eol-code* *eol-lf*))
    (declare (special *expected-fileio-encoding* *expected-eol-code*))
    (find-file filename *encoding-binary*))
  (clear-message)
  (unless (eq buffer-mode 'hexl-mode)
    (hexl-mode)))

(defun hexl-mode-exit (&optional arg)
  "Exit Hexl mode, returning to previous mode.
With arg, don't unhexlify buffer."
  (interactive "p")
  (unless arg
    (let ((p (hexl-current-address))
          (buffer-read-only nil))
      (declare (special buffer-read-only))
      (dehexlify-buffer)
      (goto-char p)))
  (delete-hook '*post-command-hook* 'hexl-ascii-overlay-hook)
  (funcall hexl-mode-old-major-mode))

(defun hexl-current-address (&optional validate)
  "Return current hexl-address."
  (interactive)
  (let ((current-column (- (current-column) 10))
	(hexl-address 0))
    (if (< current-column 0)
	(if validate
	    (error "Point is not on a character in the file")
	  (setq current-column 0)))
    (setq hexl-address
	  (+ (* (1- (current-line-number)) 16)
	     (if (>= current-column 41)
		 (- current-column 41)
	       (floor (- current-column  (floor current-column 5)) 2))))
    (when (interactive-p)
      (message "Current address is ~D" hexl-address))
    hexl-address))

(defun hexl-address-to-marker (address)
  "Return buffer position for ADDRESS."
  (+ (* (floor address 16) 68) 10 (floor (* (mod address 16) 5) 2)))

(defun hexl-goto-address (address)
  "Goto hexl-mode (decimal) address ADDRESS.
Signal error if ADDRESS out of range."
  (interactive "nAddress: ")
  (if (or (< address 0) (> address hexl-max-address))
	  (error "Out of hexl region"))
  (goto-char (hexl-address-to-marker address)))

(defun hexl-goto-hex-address (hex-address)
  "Go to hexl-mode address (hex string) HEX-ADDRESS.
Signal error if HEX-ADDRESS is out of range."
  (interactive "sHex Address: ")
  (hexl-goto-address (hexl-hex-string-to-integer hex-address)))

(defun hexl-hex-string-to-integer (hex-string)
  "Return decimal integer for HEX-STRING."
  (parse-integer hex-string :radix 16))

(defun hexl-octal-string-to-integer (octal-string)
  "Return decimal integer for OCTAL-STRING."
  (parse-integer octal-string :radix 8))

;; move point functions

(defun hexl-backward-char (&optional (arg 1))
  "Move to left ARG bytes (right if ARG negative) in hexl-mode."
  (interactive "p")
  (hexl-goto-address (- (hexl-current-address) arg)))

(defun hexl-forward-char (&optional (arg 1))
  "Move right ARG bytes (left if ARG negative) in hexl-mode."
  (interactive "p")
  (hexl-goto-address (+ (hexl-current-address) arg)))

(defun hexl-backward-short (&optional (arg 1))
  "Move to left ARG shorts (right if ARG negative) in hexl-mode."
  (interactive "p")
  (cond ((zerop arg) nil)
        ((minusp arg) (hexl-forward-short (- arg)))
        ((zerop (hexl-current-address))
         (message "Beginning of buffer."))
        (t
         (hexl-goto-address (* 4 (- (floor (1- (hexl-current-address)) 4) (1- arg)))))))

(defun hexl-forward-short (&optional (arg 1))
  "Move right ARG shorts (left if ARG negative) in hexl-mode."
  (interactive "p")
  (cond ((zerop arg) nil)
        ((minusp arg) (hexl-backward-short (- arg)))
        ((<= hexl-max-address (hexl-current-address))
         (message "End of buffer."))
        (t
         (let ((address (1- (* 4 (+ arg (floor (1+ (hexl-current-address)) 4))))))
           (and (= arg 1) (> address hexl-max-address) (setq address hexl-max-address))
           (hexl-goto-address address)))))

(defun hexl-backward-word (&optional (arg 1))
  "Move to left ARG words (right if ARG negative) in hexl-mode."
  (interactive "p")
  (cond ((zerop arg) nil)
        ((minusp arg) (hexl-forward-short (- arg)))
        ((zerop (hexl-current-address))
         (message "Beginning of buffer."))
        (t
         (hexl-goto-address (* 8 (- (floor (1- (hexl-current-address)) 8) (1- arg)))))))

(defun hexl-forward-word (&optional (arg 1))
  "Move right ARG words (left if ARG negative) in hexl-mode."
  (interactive "p")
  (cond ((zerop arg) nil)
        ((minusp arg) (hexl-backward-word (- arg)))
        ((<= hexl-max-address (hexl-current-address))
         (message "End of buffer."))
        (t
         (let ((address (1- (* 8 (+ arg (floor (1+ (hexl-current-address)) 8))))))
           (and (= arg 1) (> address hexl-max-address) (setq address hexl-max-address))
           (hexl-goto-address address)))))

(defun hexl-previous-line (&optional (arg 1))
  "Move vertically up ARG lines [16 bytes] (down if ARG negative) in hexl-mode.
If there is byte at the target address move to the last byte in that line."
  (interactive "p")
  (hexl-next-line (- arg)))

(defun hexl-next-line (&optional (arg 1))
  "Move vertically down ARG lines [16 bytes] (up if ARG negative) in hexl-mode.
If there is no byte at the target address move to the last byte in that line."
  (interactive "p")
  (hexl-goto-address (let ((address (+ (hexl-current-address) (* arg 16))))
		       (if (and (< arg 0) (< address 0))
				(progn (message "Out of hexl region.")
				       (setq address
					     (mod (hexl-current-address) 16)))
			 (if (and (> address hexl-max-address)
				  (< (mod hexl-max-address 16) (mod address 16)))
			     (setq address hexl-max-address)
			   (if (> address hexl-max-address)
			       (progn (message "Out of hexl region.")
				      (setq
				       address
				       (+ (logand hexl-max-address -16)
					  (mod (hexl-current-address) 16)))))))
		       address)))

(defun hexl-beginning-of-buffer (&optional (arg 1))
  "Move to the beginning of the hexl buffer.
Leaves `hexl-mark' at previous position.
With prefix arg N, puts point N bytes of the way from the true beginning."
  (interactive "p")
  (set-mark (point))
  (hexl-goto-address (+ 0 (1- arg))))

(defun hexl-end-of-buffer (&optional (arg 1))
  "Go to `hexl-max-address' minus ARG."
  (interactive "p")
  (set-mark (point))
  (hexl-goto-address (- hexl-max-address (1- arg))))

(defun hexl-beginning-of-line ()
  "Goto beginning of line in hexl mode."
  (interactive)
  (goto-column 10))

(defun hexl-end-of-line ()
  "Goto end of line in hexl mode."
  (interactive)
  (hexl-goto-address (let ((address (logior (hexl-current-address) 15)))
		       (if (> address hexl-max-address)
			   (setq address hexl-max-address))
		       address)))

(defun hexl-scroll-down (&optional (arg (window-height)))
  "Scroll hexl buffer window upward ARG lines; or near full window if no ARG."
  (interactive "p")
  (hexl-scroll-up (- arg)))

(defun hexl-scroll-up (&optional (arg (window-height)))
  "Scroll hexl buffer window upward ARG lines; or near full window if no ARG.
If there's no byte at the target address, move to the first or last line."
  (interactive "p")
  (let* ((movement (* arg 16))
	 (address (hexl-current-address))
	 (dest (+ address movement)))
    (cond
     ;; If possible, try to stay at the same offset from the beginning
     ;; of the 16-byte group, even if we move to the first or last
     ;; group.
     ((and (> dest hexl-max-address)
	   (>= (mod hexl-max-address 16) (mod address 16)))
      (setq dest (+ (logand hexl-max-address -16) (mod address 16))))
     ((> dest hexl-max-address)
      (setq dest hexl-max-address))
     ((< dest 0)
      (setq dest (mod address 16))))
    (if (/= dest (+ address movement))
	(message "Out of hexl region."))
    (hexl-goto-address dest)
    (recenter 0)))

(defun hexl-beginning-of-1k-page ()
  "Go to beginning of 1k boundary."
  (interactive)
  (hexl-goto-address (logand (hexl-current-address) -1024)))

(defun hexl-end-of-1k-page ()
  "Go to end of 1k boundary."
  (interactive)
  (hexl-goto-address (let ((address (logior (hexl-current-address) 1023)))
		       (if (> address hexl-max-address)
			   (setq address hexl-max-address))
		       address)))

(defun hexl-beginning-of-512b-page ()
  "Go to beginning of 512 byte boundary."
  (interactive)
  (hexl-goto-address (logand (hexl-current-address) -512)))

(defun hexl-end-of-512b-page ()
  "Go to end of 512 byte boundary."
  (interactive)
  (hexl-goto-address (let ((address (logior (hexl-current-address) 511)))
		       (if (> address hexl-max-address)
			   (setq address hexl-max-address))
		       address)))

(defun hexl-quoted-insert (&optional (arg 1))
  "Read next input character and insert it.
Useful for inserting control characters and non-ASCII characters given their
numerical code.
You may also type octal digits, to insert a character with that code."
  (interactive "p")
  (hexl-insert-multibyte-char (ed::quote-char-read) arg))

;00000000: 0011 2233 4455 6677 8899 aabb ccdd eeff  0123456789ABCDEF

;;;###autoload
(defun hexlify-buffer ()
  "Convert a binary buffer to hexl format.
This discards the buffer's undo information."
  (and (buffer-modified-p)
       (not (y-or-n-p "Converting to hexl format discards undo info; ok? "))
       (error "Aborted"))
  (setq kept-undo-information nil)
  (execute-shell-command (format nil "~A \"~A\"" hexlify-command (get-buffer-file-name)) t (selected-buffer))
  (setq kept-undo-information (default-value 'kept-undo-information))
  (if (< (current-column) 10) (goto-column 10))
  (if (> (point) (hexl-address-to-marker hexl-max-address))
      (hexl-goto-address hexl-max-address)))

(defun dehexlify-buffer ()
  "Convert a hexl format buffer to binary.
This discards the buffer's undo information."
  (and (buffer-modified-p)
       (not (y-or-n-p "Converting from hexl format discards undo info; ok? "))
       (error "Aborted"))
  (setq kept-undo-information nil)
  (filter-buffer dehexlify-command)
  (set-buffer-modified-p nil)
  (setq kept-undo-information (default-value 'kept-undo-information)))

(defun hexl-char-after-point ()
  "Return char for ASCII hex digits at point."
  (hexl-htoi (char-after (point))
	     (char-after (1+ (point)))))

(defun hexl-htoi (lh rh)
  "Hex (char) LH (char) RH to integer."
    (+ (* (hexl-hex-char-to-integer lh) 16)
       (hexl-hex-char-to-integer rh)))

(defun hexl-hex-char-to-integer (character)
  "Take a char and return its value as if it was a hex digit."
  (if (or (char-not-greaterp #\0 character #\9) (char-not-greaterp #\a character #\f))
      (digit-char-p character 16)
    (error "Invalid hex digit `~C'" character)))

(defun hexl-oct-char-to-integer (character)
  "Take a char and return its value as if it was a octal digit."
  (if (char-not-greaterp #\0 character #\7)
      (digit-char-p character 8)
    (error "Invalid octal digit `~C'" character)))

(defun hexl-printable-character (ch)
  "Return a displayable string for character CH."
  (format nil "~C" (if hexl-iso
                       (if (or (char< ch #\SPC) (char<= #\DEL ch #\x9f))
                           #\.
                         ch)
                     (if (or (char< ch #\SPC) (char>= ch #\DEL))
                         #\.
                       ch))))

(defun hexl-insert-multibyte-char (ch num)
  "Insert a possibly multibyte character CH NUM times.

Non-ASCII characters are first encoded with `buffer-file-coding-system',
and their encoded form is inserted byte by byte."
  (cond ((char<= #\x00 ch #\xff)
         (hexl-insert-char ch num))
        (t
         (let (encoded)
           (let* ((src (si:make-string-chunk (format nil "~C" ch)))
                  (size (si:chunk-size src))
                  (chunk (si:make-chunk nil size src 0)))
             (dotimes (i (1- size))
               (push (si:unpack-uint8 chunk i) encoded)))
           (setq encoded (nreverse encoded))
           (dotimes (i num)
             (dolist (c encoded)
               (hexl-insert-char c 1)))
           ))))

(defun hexl-self-insert-command (&optional (arg 1))
  "Insert this character.
Interactively, with a numeric argument, insert this character that many times.

Non-ASCII characters are first encoded with `buffer-file-coding-system',
and their encoded form is inserted byte by byte."
  (interactive "p")
  (hexl-insert-multibyte-char *last-command-char* arg))

(defun hexl-insert-char (ch &optional (num 1))
  "Insert the character CH NUM times in a hexl buffer.

CH must be a unibyte character whose value is between 0 and 255."
  (if (not (char<= #\x0 ch #\xff))
      (error "Invalid character 0x%x -- must be in the range [0..255]"))
  (let ((address (hexl-current-address t)))
    (dotimes (i num)
      (let ((hex-position
	     (+ (* (floor address 16) 68)
		10
		(* 2 (mod address 16))
		(floor (mod address 16) 2)))
	    (ascii-position
	     (+ (* (floor address 16) 68) 51 (mod address 16)))
	    at-ascii-position)
	(if (= (point) ascii-position)
	    (setq at-ascii-position t))
	(goto-char hex-position)
	(delete-char 2)
        (insert (format nil "~2,'0x" (char-code ch)))
	(goto-char ascii-position)
	(delete-char 1)
	(insert (hexl-printable-character ch))
	(or (eq address hexl-max-address)
	    (setq address (1+ address)))
	(hexl-goto-address address)
	(if at-ascii-position
	    (progn
              (goto-column 50)
	      (forward-char (mod address 16)))))
      )))

;; hex conversion

(defun hexl-insert-hex-char (&optional (arg 1))
  "Insert a character given by its hexadecimal code ARG times at point."
  (interactive "p")
  (let ((num (hexl-hex-string-to-integer (read-string "Hex number: "))))
    (if (< num 0)
        (error "Hex number out of range")
      (hexl-insert-multibyte-char (code-char num) arg))))

(defun hexl-insert-hex-string (str &optional (arg 1))
  "Insert hexadecimal string STR at point ARG times.
Embedded whitespace, dashes, and periods in the string are ignored."
  (interactive "sHex string: \np")
  (setq str (substitute-string "[- \t.]" "" str))
  (let ((chars '()))
    (let ((len (length str))
	  (idx 0))
      (if (eq (logand len 1) 1)
	  (let ((num (hexl-hex-string-to-integer (substring str 0 1))))
	    (setq chars (cons num chars))
	    (setq idx 1)))
      (while (< idx len)
	(let* ((nidx (+ idx 2))
	       (num (hexl-hex-string-to-integer (substring str idx nidx))))
	  (setq chars (cons num chars))
	  (setq idx nidx))))
    (setq chars (nreverse chars))
    (dotimes (i arg)
      (dolist (c chars)
        (hexl-insert-char c 1)))))

(defun hexl-insert-decimal-char (&optional (arg 1))
  "Insert a character given by its decimal code ARG times at point."
  (interactive "p")
  (let ((num (parse-integer (read-string "Decimal Number: "))))
    (if (< num 0)
        (error "Decimal number out of range")
      (hexl-insert-multibyte-char (code-char num) arg))))

(defun hexl-insert-octal-char (arg)
  "Insert a character given by its octal code ARG times at point."
  (interactive "p")
  (let ((num (hexl-octal-string-to-integer (read-string "Octal Number: "))))
    (if (< num 0)
        (error "Decimal number out of range")
      (hexl-insert-multibyte-char (code-char num) arg))))

(defun hexl-follow-ascii (&optional (arg nil sv))
  "Toggle following ASCII in Hexl buffers.
With prefix ARG, turn on following if and only if ARG is positive.
When following is enabled, the ASCII character corresponding to the
element under the point is highlighted.
Customize the variable `hexl-follow-ascii' to disable this feature."
  (interactive "p")
  (ed::toggle-mode 'hexl-ascii-overlay arg sv)
  (cond (hexl-ascii-overlay
         (add-hook '*post-command-hook* 'hexl-ascii-overlay-hook)
         (setq hexl-follow-ascii t))
        (t
         (clear-reverse-region)
         (setq hexl-follow-ascii nil)
         (delete-hook '*post-command-hook* 'hexl-ascii-overlay-hook))))

(defun hexl-ascii-overlay-hook ()
  (if (eq buffer-mode 'hexl-mode)
      (hexl-follow-ascii-find)))

(defun hexl-follow-ascii-find ()
  "Find and highlight the ASCII element corresponding to current point."
  (let ((pos (+ 51
                (- (point) (current-column))
                (mod (hexl-current-address) 16))))
    (reverse-region pos (1+ pos))))

;; startup stuff.

(unless hexl-mode-map
  (setq hexl-mode-map (make-keymap))
  ;; Make all self-inserting keys go through hexl-self-insert-command,
  ;; because we need to convert them to unibyte characters before
  ;; inserting them into the buffer.
  (substitute-key-definition 'self-insert-command 'hexl-self-insert-command
			     hexl-mode-map *global-keymap*)

  (define-key hexl-mode-map #\RET 'hexl-self-insert-command)
  (define-key hexl-mode-map #\LFD 'hexl-self-insert-command)
  (define-key hexl-mode-map #\Left 'hexl-backward-char)
  (define-key hexl-mode-map #\Right 'hexl-forward-char)
  (define-key hexl-mode-map #\Up 'hexl-previous-line)
  (define-key hexl-mode-map #\Down 'hexl-next-line)
  (define-key hexl-mode-map #\M-Left 'hexl-backward-short)
  (define-key hexl-mode-map #\M-Right 'hexl-forward-short)
  (define-key hexl-mode-map #\PageUp 'hexl-scroll-down)
  (define-key hexl-mode-map #\PageDown 'hexl-scroll-up)
  (define-key hexl-mode-map #\Home 'hexl-beginning-of-line)
  (define-key hexl-mode-map #\End 'hexl-end-of-line)

  (define-key hexl-mode-map #\C-a 'hexl-beginning-of-line)
  (define-key hexl-mode-map #\C-b 'hexl-backward-char)
  (define-key hexl-mode-map #\C-d 'undefined)
  (define-key hexl-mode-map #\C-e 'hexl-end-of-line)
  (define-key hexl-mode-map #\C-f 'hexl-forward-char)

  (define-key hexl-mode-map #\C-h 'undefined)
  (define-key hexl-mode-map #\C-k 'undefined)
  (define-key hexl-mode-map #\C-n 'hexl-next-line)
  (define-key hexl-mode-map #\C-o 'undefined)
  (define-key hexl-mode-map #\C-p 'hexl-previous-line)
  (define-key hexl-mode-map #\C-q 'hexl-quoted-insert)
  (define-key hexl-mode-map #\C-t 'undefined)
  (define-key hexl-mode-map #\C-v 'hexl-scroll-up)
  (define-key hexl-mode-map #\C-w 'undefined)
  (define-key hexl-mode-map #\C-y 'undefined)
  (define-key hexl-mode-map #\DEL 'undefined)
  (define-key hexl-mode-map #\Delete 'undefined)
  (define-key hexl-mode-map #\Insert 'undefined)

  (define-key hexl-mode-map #\S-PageUp 'undefined)
  (define-key hexl-mode-map #\S-PageDown 'undefined)
  (define-key hexl-mode-map #\S-End 'undefined)
  (define-key hexl-mode-map #\S-Home 'undefined)
  (define-key hexl-mode-map #\S-Left 'undefined)
  (define-key hexl-mode-map #\S-Up 'undefined)
  (define-key hexl-mode-map #\S-Right 'undefined)
  (define-key hexl-mode-map #\S-Down 'undefined)
  
  (define-key hexl-mode-map #\C-Insert 'undefined)
  (define-key hexl-mode-map #\C-Delete 'undefined)
  (define-key hexl-mode-map #\S-C-Insert 'undefined)

  (define-key hexl-mode-map #\C-End 'hexl-end-of-buffer)
  (define-key hexl-mode-map #\C-Home 'hexl-beginning-of-buffer)
  (define-key hexl-mode-map #\C-Left 'undefined)
  (define-key hexl-mode-map #\C-Up 'undefined)
  (define-key hexl-mode-map #\C-Right 'undefined)
  (define-key hexl-mode-map #\C-Down 'undefined)

  (define-key hexl-mode-map #\S-C-End 'undefined)
  (define-key hexl-mode-map #\S-C-Home 'undefined)
  (define-key hexl-mode-map #\S-C-Left 'undefined)
  (define-key hexl-mode-map #\S-C-Up 'undefined)
  (define-key hexl-mode-map #\S-C-Right 'undefined)
  (define-key hexl-mode-map #\S-C-Down 'undefined)

  (define-key hexl-mode-map '(#\ESC #\C-a) 'hexl-beginning-of-512b-page)
  (define-key hexl-mode-map '(#\ESC #\C-b) 'hexl-backward-short)
  (define-key hexl-mode-map '(#\ESC #\C-d) 'hexl-insert-decimal-char)
  (define-key hexl-mode-map '(#\ESC #\C-e) 'hexl-end-of-512b-page)
  (define-key hexl-mode-map '(#\ESC #\C-f) 'hexl-forward-short)
  (define-key hexl-mode-map '(#\ESC #\C-h) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-i) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-j) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-k) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-n) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-o) 'hexl-insert-octal-char)
  (define-key hexl-mode-map '(#\ESC #\C-p) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-q) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-r) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-t) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-u) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\C-x) 'hexl-insert-hex-char)
  (define-key hexl-mode-map '(#\ESC #\C-%) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\%) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\/) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\;) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\\) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\^) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\b) 'hexl-backward-word)
  (define-key hexl-mode-map '(#\ESC #\c) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\d) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\f) 'hexl-forward-word)
  (define-key hexl-mode-map '(#\ESC #\g) 'hexl-goto-hex-address)
  (define-key hexl-mode-map '(#\ESC #\i) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\j) 'hexl-goto-address)
  (define-key hexl-mode-map '(#\ESC #\k) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\l) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\q) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\r) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\s) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\t) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\u) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\v) 'hexl-scroll-down)
  (define-key hexl-mode-map '(#\ESC #\y) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\z) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\<) 'hexl-beginning-of-buffer)
  (define-key hexl-mode-map '(#\ESC #\>) 'hexl-end-of-buffer)
  (define-key hexl-mode-map '(#\ESC #\{) 'undefined)
  (define-key hexl-mode-map '(#\ESC #\}) 'undefined)

  (define-key hexl-mode-map '(#\C-c #\C-c) 'hexl-mode-exit)

  (define-key hexl-mode-map '(#\C-x #\#) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\i) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\[) 'hexl-beginning-of-1k-page)
  (define-key hexl-mode-map '(#\C-x #\]) 'hexl-end-of-1k-page)
  (define-key hexl-mode-map '(#\C-x #\|) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\C-l) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\C-p) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\C-r) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\C-s) 'hexl-save-buffer)
  (define-key hexl-mode-map '(#\C-x #\C-t) 'undefined)
  (define-key hexl-mode-map '(#\C-x #\C-u) 'undefined))

(provide "hexl/hexl")

;;; hexl.el ends here
