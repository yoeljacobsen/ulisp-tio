;; Sudoku solver for uLisp
;;
;; (solve board)            Returns a solved copy of board (a 9x9 array, 0 = empty), or nil
;;                          if it has no solution. The board passed in is not changed.
;; (print-board board)      Prints a board.
;; (valid-solution-p puzzle solution)
;;                          t if solution is complete, follows the rules, and keeps the
;;                          puzzle's clues.
;; (solve-all "file.csv")   Solves and verifies every puzzle in a CSV file on the flash, and
;;                          prints timing statistics. Each line is: puzzle,solution
;;                          (81 digits each, 0 or . for empty; the solution is optional).
;;                          A header line is skipped.
;;
;; Example: (print-board (solve board))

(defvar board #2a((0 6 0 1 0 4 0 5 0)
                  (0 0 8 3 0 5 6 0 0)
                  (2 0 0 0 0 0 0 0 1)
                  (8 0 0 4 0 7 0 0 6)
                  (0 0 6 0 0 0 3 0 0)
                  (7 0 0 9 0 1 0 0 4)
                  (5 0 0 0 0 0 0 0 2)
                  (0 0 7 2 0 6 9 0 0)
                  (0 4 0 5 0 8 0 7 0)))

;; Boards

(defun new-board () (make-array '(9 9) :initial-element 0))

(defun copy-board (b)
  (let ((new (new-board)))
    (dotimes (r 9 new)
      (dotimes (c 9)
        (setf (aref new r c) (aref b r c))))))

(defun box (r c) (+ (* 3 (truncate r 3)) (truncate c 3)))

(defun print-board (b)
  (dotimes (r 9)
    (if (zerop (mod r 3))
        (format t "~%+-------+-------+-------+~%|")
      (format t "~%|"))
    (dotimes (c 9)
      (let ((n (aref b r c)))
        (format t " ~a" (if (zerop n) "." n))
        (when (= 2 (mod c 3)) (format t " |")))))
  (format t "~%+-------+-------+-------+~%")
  nothing)

;; Solver
;;
;; rows, cols and boxes hold a bit mask for each row, column and 3x3 box: bit n is set when
;; the digit n is used there. cells is an array of the empty cells, as r*9+c; cells d to m-1
;; are still to fill. Each step fills the cell with the fewest possible digits first, which
;; keeps the search small. The recursion only goes as deep as the number of empty cells.

;; Number of set bits in 0 to 15, and the box number of each cell (indexed by r*9+c)
(defvar *nibble-bits* #(0 1 1 2 1 2 2 3 1 2 2 3 2 3 3 4))
(defvar *cell-box* (make-array 81 :initial-element 0))
(dotimes (i 81) (setf (aref *cell-box* i) (box (truncate i 9) (mod i 9))))

(defun fill-cells (b cells d m rows cols boxes)
  (if (= d m) t
    ;; Find the remaining cell with the fewest candidates; stop early at 0 or 1.
    ;; Inlined, because function calls are slow in uLisp.
    (let ((best d) (most -1) (j d) (nb *nibble-bits*) (cb *cell-box*))
      (loop
       (when (or (= j m) (>= most 8)) (return))
       (let* ((i (aref cells j))
              (u (logior (aref rows (truncate i 9)) (aref cols (mod i 9)) (aref boxes (aref cb i))))
              (n (+ (aref nb (logand u 15)) (aref nb (logand (ash u -4) 15)) (aref nb (ash u -8)))))
         (when (> n most) (setq best j most n)))   ; Most digits used = fewest candidates
       (incf j))
      (unless (= most 9)                             ; A cell with no candidates: dead end
        (let ((tmp (aref cells d)))
          (setf (aref cells d) (aref cells best))
          (setf (aref cells best) tmp))
        (let* ((i (aref cells d))
               (r (truncate i 9))
               (c (mod i 9))
               (x (box r c))
               (used (logior (aref rows r) (aref cols c) (aref boxes x))))
          (dotimes (k 9 (progn (setf (aref b r c) 0) nil))
            (let ((bit (ash 1 (1+ k))))
              (when (zerop (logand used bit))
                (setf (aref b r c) (1+ k))
                (setf (aref rows r) (logior (aref rows r) bit))
                (setf (aref cols c) (logior (aref cols c) bit))
                (setf (aref boxes x) (logior (aref boxes x) bit))
                (when (fill-cells b cells (1+ d) m rows cols boxes) (return t))
                (setf (aref rows r) (logxor (aref rows r) bit))
                (setf (aref cols c) (logxor (aref cols c) bit))
                (setf (aref boxes x) (logxor (aref boxes x) bit))))))))))

(defun solve (puzzle)
  (let ((b (copy-board puzzle))
        (rows (make-array 9 :initial-element 0))
        (cols (make-array 9 :initial-element 0))
        (boxes (make-array 9 :initial-element 0))
        (cells nil)
        (ok t))
    ;; Record the clues; a repeated clue means there is no solution
    (dotimes (r 9)
      (dotimes (c 9)
        (let ((n (aref b r c)))
          (if (zerop n)
              (push (+ (* r 9) c) cells)
            (let ((bit (ash 1 n)) (x (box r c)))
              (when (plusp (logand bit (logior (aref rows r) (aref cols c) (aref boxes x))))
                (setq ok nil))
              (setf (aref rows r) (logior (aref rows r) bit))
              (setf (aref cols c) (logior (aref cols c) bit))
              (setf (aref boxes x) (logior (aref boxes x) bit)))))))
    (cond
     ((not ok) nil)
     ((null cells) b)                                ; Already complete
     (t (let* ((m (length cells))
               (arr (make-array m :initial-element 0))
               (j 0))
          (dolist (i (reverse cells)) (setf (aref arr j) i) (incf j))
          (when (fill-cells b arr 0 m rows cols boxes) b))))))

;; Verification: every row, column and box holds 1 to 9, and the clues are unchanged

(defun valid-solution-p (puzzle solution)
  (let ((rows (make-array 9 :initial-element 0))
        (cols (make-array 9 :initial-element 0))
        (boxes (make-array 9 :initial-element 0))
        (ok t))
    (dotimes (r 9)
      (dotimes (c 9)
        (let ((n (aref solution r c)) (p (aref puzzle r c)) (x (box r c)))
          (when (or (< n 1) (> n 9) (and (plusp p) (/= p n))) (setq ok nil))
          (when ok
            (let ((bit (ash 1 n)))
              (setf (aref rows r) (logior (aref rows r) bit))
              (setf (aref cols c) (logior (aref cols c) bit))
              (setf (aref boxes x) (logior (aref boxes x) bit)))))))
    (when ok
      (dotimes (i 9)
        (unless (= #x3FE (aref rows i) (aref cols i) (aref boxes i)) (setq ok nil))))
    ok))

(defun same-board-p (a b)
  (let ((ok t))
    (dotimes (r 9 ok)
      (dotimes (c 9)
        (unless (= (aref a r c) (aref b r c)) (setq ok nil))))))

;; CSV files

(defun string-to-board (s start)
  "Board from the 81 characters of s starting at start; 0 or . is an empty cell."
  (let ((b (new-board)))
    (dotimes (i 81 b)
      (let ((ch (char s (+ start i))))
        (setf (aref b (truncate i 9) (mod i 9))
              (if (eq ch #\.) 0 (- (char-code ch) 48)))))))

(defun digit-char-p* (ch) (or (eq ch #\.) (<= 48 (char-code ch) 57)))

(defun parse-line (line)
  "Returns (puzzle solution) for a CSV line, solution nil if missing, or nil if not a puzzle."
  (when (and (>= (length line) 81) (digit-char-p* (char line 0)))
    (list (string-to-board line 0)
          (when (>= (length line) 163) (string-to-board line 82)))))

(defun solve-all (filename)
  (let ((n 0) (solved 0) (correct 0) (nosolution 0) (wrong 0) (mismatch 0)
        (total 0) (fastest nil) (slowest 0) (fastest-n 0) (slowest-n 0) (times nil)
        (start-all (millis)))
    (format t "~%Solving puzzles in ~a~%~%" filename)
    (with-sd-card (str filename)
      (loop
       (let ((line (read-line str)))
         (unless line (return))
         (let ((puz (parse-line line)))
           (when puz
             (incf n)
             (let* ((puzzle (first puz))
                    (expected (second puz))
                    (t0 (millis))
                    (sol (solve puzzle))
                    (ms (- (millis) t0))
                    (status "ok"))
               (push ms times)
               (incf total ms)
               (when (or (null fastest) (< ms fastest)) (setq fastest ms fastest-n n))
               (when (> ms slowest) (setq slowest ms slowest-n n))
               (cond
                ((null sol) (incf nosolution) (setq status "NO SOLUTION"))
                ((not (valid-solution-p puzzle sol)) (incf wrong) (setq status "INVALID"))
                ((and expected (not (same-board-p sol expected)))
                 (incf solved) (incf mismatch) (setq status "valid, differs from file"))
                (t (incf solved) (incf correct)))
               (format t "Puzzle ~a: ~a ms ~a~%" n ms status)))))))
    (format t "~%Puzzles:            ~a~%" n)
    (format t "Solved and valid:   ~a~%" solved)
    (format t "Match the file:     ~a~%" correct)
    (when (plusp mismatch) (format t "Differ from file:   ~a (puzzle has several solutions)~%" mismatch))
    (when (plusp nosolution) (format t "No solution:        ~a~%" nosolution))
    (when (plusp wrong) (format t "INVALID solutions:  ~a~%" wrong))
    (when (plusp n)
      (let ((sorted (sort times #'<)))
        (format t "~%Total solve time:   ~a ms~%" total)
        (format t "Average:            ~a ms~%" (/ (round (* 10 total) n) 10.0))
        (format t "Median:             ~a ms~%"
                (if (oddp n) (nth (truncate n 2) sorted)
                  (/ (+ (nth (1- (truncate n 2)) sorted) (nth (truncate n 2) sorted)) 2.0)))
        (format t "Fastest:            ~a ms (puzzle ~a)~%" fastest fastest-n)
        (format t "Slowest:            ~a ms (puzzle ~a)~%" slowest slowest-n)
        (format t "Wall time:          ~a ms (including reading and checking)~%"
                (- (millis) start-all))))
    (= n correct)))
