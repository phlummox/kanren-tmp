(load "shift-reset.scm")

; data H a b = H a b | HV Value
; Conceptually, it's an algebraic data type with two constructors
; H and HV and a deconstructor case-H.
; Here's another, potentially more efficient implementation of the H datatype,
; as an indiscriminated Scheme union

(define H-tag (list 'H-tag))

; Constructors
(define H
  (lambda (a b)
    (cons H-tag (cons a b))))

(define-syntax HV                        ; just the identity
  (syntax-rules ()
    ((HV v) v)))

; (define HV-tag (list 'HV-tag)) ; for better error checking
; (define HV
;   (lambda (a)
;     (cons HV-tag a)))

; Deconstructor
(define-syntax case-H
  (syntax-rules ()
    ((case-H e
       ((f x) on-h)
       (v on-hv))
     (let ((val e))
       (if (and (pair? val) (eq? (car val) H-tag))
         (let ((f (cadr val)) (x (cddr val))) on-h)
         (let ((v val)) on-hv))))))

'(define-syntax case-H
  (syntax-rules ()
    ((case-H e
       ((f x) on-h)
       (v on-hv))
     (let ((val e))
       (cond
	 ((and (pair? val) (eq? (car val) H-tag))
	   (let ((f (cadr val)) (x (cddr val))) on-h))
	 ((and (pair? val) (eq? (car val) HV-tag))
	   (let ((v (cdr val))) on-hv))
	 (else (error "untagged val: ~a~n" val)))))))

(define nl (string #\newline))

(define (cout . args)
  (for-each (lambda (x)
              (if (procedure? x) (x) (display x)))
            args))

;;; This file was generated by writeminikanren.pl
;;; Generated at 2005-03-02 21:26:02

(define-syntax lambdag@
  (syntax-rules ()
    ((_ (s) e) (lambda (s) e))))

(define-syntax lambdaf@
  (syntax-rules ()
    ((_ () e) (lambda () e))))

(define rhs cdr)
(define lhs car)
(define var vector)
(define var? vector?)

(define var                                                                    
  (lambda (name)                                                        
    (vector name)))

(define var? (lambda (v) (vector? v)))  
(define empty-s '())
 
(define walk
  (Lambda (x s)
    (cond
      ((assq x s) =>
       (lambda (a)
         (let ((v (rhs a)))
           (cond
             ((var? v) (walk v s))
             (else v)))))
      (else x))))

(define ext-s
  (lambda (x v s)
    (cons `(,x . ,v) s)))
 
(define unify
  (lambda (v w s)
    (let ((v (if (var? v) (walk v s) v))
          (w (if (var? w) (walk w s) w)))
      (cond
        ((eq? v w) s)
        ((var? v) (ext-s v w s))
        ((var? w) (ext-s w v s))
        ((and (pair? v) (pair? w))
         (cond
           ((unify (car v) (car w) s) =>
            (lambda (s)
              (unify (cdr v) (cdr w) s)))
           (else #f)))
        ((equal? v w) s)
        (else #f)))))

(define ext-s-check
  (lambda (x v s)
    (cond
      ((occurs? x v s) #f)
      (else (ext-s x v s)))))

(define occurs?
  (lambda (x v s)
    (cond
      ((var? v)
       (let ((v (walk v s)))
         (cond
           ((var? v) (eq? v x))
           (else (occurs? x v s)))))
      ((pair? v) 
       (or 
         (occurs? x (car v) s)
         (occurs? x (cdr v) s)))
      (else #f))))

(define unify-check
  (lambda (v w s)
    (let ((v (if (var? v) (walk v s) v))
          (w (if (var? w) (walk w s) w)))
      (cond
        ((eq? v w) s)
        ((var? v) (ext-s-check v w s))
        ((var? w) (ext-s-check w v s))
        ((and (pair? v) (pair? w))
         (cond
           ((unify-check (car v) (car w) s) =>
            (lambda (s)
              (unify-check (cdr v) (cdr w) s)))
           (else #f)))
        ((equal? v w) s)
        (else #f)))))

(define walk*
  (lambda (v s)
    (cond
      ((var? v)
       (let ((v (walk v s)))
         (cond
           ((var? v) v)
           (else (walk* v s)))))
      ((pair? v)
       (cons 
         (walk* (car v) s)
         (walk* (cdr v) s)))
      (else v))))

(define reify
  (lambda (v)
    (let ((fx (fresh-vars v)))
      (let ((fn (fresh-names fx)))
        (walk* v (zip-s fx fn))))))
 
(define zip-s
  (lambda (fx fn)
    (cond
      ((null? fx) empty-s)
      (else 
        (ext-s (car fx) (car fn)
          (zip-s (cdr fx) (cdr fn)))))))

(define fresh-vars
  (lambda (v)
    (reverse (fv v '()))))

(define fv
  (lambda (v acc)
    (cond
      ((var? v) 
       (cond
         ((memq v acc) acc)
         (else (cons v acc))))
      ((pair? v) 
       (fv (cdr v) (fv (car v) acc)))
      (else acc))))

(define fresh-names
  (lambda (fx)
    (fn fx 0)))

(define fn
  (lambda (fx c)
    (cond
      ((null? fx) '())
      (else
        (cons (reify-id c)
          (fn (cdr fx) (+ c 1)))))))

(define reify-id
  (lambda (c)
    (string->symbol
      (string-append
        "_."
        (number->string c)))))

(define-syntax case-ans
  (syntax-rules ()
    ((_ e on-zero ((a^) on-one) ((a f) on-choice))
     (let ((r e))
       (cond
         ((not r) on-zero)
         ((and (pair? r) (procedure? (cdr r)))
          (let ((a (car r)) 
                (f (cdr r)))
            on-choice))
         (else (let ((a^ r)) on-one)))))))

(define-syntax mzero
  (syntax-rules ()
    ((_) #f)))

(define-syntax unit        
  (syntax-rules ()
    ((_ a) a)))

(define-syntax choice
  (syntax-rules ()
    ((_ a f) (cons a f))))

; ``Operating system calls''
(define yield
  (lambda ()
    (shift f (H 'yield (lambda () (f #f))))))

(define fork-req
  (lambda ()
    (shift f (H 'fork f))))


(define scheduling-quantum 10)
(define max-queue-size 5)

; Two-queue priority scheduler
; The high-priority queue has the size of one.
; The other queue has a limited capacity to prevent unbridled speculation
; (unbridled breadth-first search)
; The tic-counter counts logical operations (essentially, unifications)

(define scheduler
  (lambda (body)
    (let loop ((tic-counter 0)
	       (high-priority-thread #f)
	       (queue '())
	       (r (reset (HV (body)))))

      (letrec
	((switch
	   (lambda (k)
	     ;(cout "Switch thread" nl)
	     (cond
	       (high-priority-thread
		 ; If we have a high-priority-thread, run it
		 (loop 0 #f (append queue (list k)) (high-priority-thread)))
	       ((null? queue)
		(loop 0 #f queue (k)))	; Nothing else to do
	       (else
		 (let ((current (car queue))
		       (queue (cdr queue)))
		   (loop 0 k queue (current)))))))

	 (other-answers
	   (lambda ()
	     (cond
	       (high-priority-thread
		 (loop 0 #f queue (high-priority-thread)))
	       ((null? queue)
		(mzero))
	       (else
		 (loop 0 #f (cdr queue) ((car queue))))))))

	(case-H r
	  ((request k)
	   (case request
	     ((yield)
	      ;  advance the counter
	      (let ((new-counter (+ 1 tic-counter)))
		;(cout "yield req: " new-counter "queue: "
		;  (length queue) nl)
		(if (> new-counter scheduling-quantum)
		  (switch k)
		  (loop new-counter high-priority-thread queue (k)))))
	     ((fork)
	       ;(cout "req choice, queue: " (length queue) nl)
	       (if  (> (length queue) max-queue-size)
		  ; decline to fork
		 (loop tic-counter high-priority-thread queue
		   (k 'denied))
		  ; fork a new thread for the alternative
		  (let ((new-thread (lambda () (k 'in-thread2))))
		    (loop tic-counter high-priority-thread
		      (append queue (list new-thread))
		      (k 'in-thread1)))))
	     (else
	       (error "~s ~s~n" "unknown scheduler request" request))))
	  ; We're finished and have an answer
	  (v 
	    (case-ans v
	      ; if we have other pending threads, run them now
	      (other-answers)
	      ((a) (choice a other-answers))
	      ((a f)
	       (choice a
		 (lambdaf@ ()
		   (loop 0 high-priority-thread queue
		     (reset (HV (f))))))))))))))



; We ask the `OS' to fork a thread.
; The OS eitehr obliges, by returning 'in-thread1
; and then _again_, 'in-thread2
; Or, OS denies the request and returns 'denied
(define choice-fork
  (lambda (chooser c1 c2) ; both c1 and c2 are thunks
    (case (fork-req)
      ((in-thread1)			; OS launched the thread
	(c1))
      ((in-thread2)			; OS launched the thread
	(c2))
      ((denied)
	; OK, run (c1) but intecept child's requests.
	; A child, c1, can't launch threads from under us
	(let loop ((r (reset (HV (c1)))))
	  (case-H r
	    ((request k)
	      (case request
		((yield)		; relay the yield request
		  (yield)
		  (loop (k)))
		((fork)
		  (case (fork-req)	; Ask the OS to fork
		    ((in-thread1)
		      (unwrap (k 'denied))) ; deny the child and detach
		    ((in-thread2)
		      (c2))
		    ((denied)		; denied again, deny the child too
		      (loop (k 'denied)))
		    (else
		      (error "bad OS fork response~n"))))
		(else
		  (error "~s ~s~n" "unknown scheduler request" request))))
	    (v				; c1 finished and yielded a value
	      (chooser v c2)))))
      (else
	(error "bad OS fork response~n")))))

; Intercept ``operating system'' calls within a thunk
; that ask for launching a thread -- and deny them
(define intercept-deny-thread-launch
  (lambda (thunk)
    (let loop ((r (reset (HV (thunk)))))
      (case-H r
	((request k)
	 (case request
	   ((fork)
	     ;;(display "intercepted choice...") (newline)
	     (loop (k 'denied)))
	   ((yield)
            ; send upstairs
            ;(display "yield...") (newline)
            (yield)
            (loop (k)))
	   (else
	     (error "~s ~s~n" "unknown scheduler request" request))))
	(v v)))))

; This is the analogue of the hr function.
; It essentially emulates `control' via shift
(define (unwrap r)
  (case-H r
    ((request k)
      (case request
	((yield)
	  (yield)
	  (unwrap (k)))
	((fork)
	  ;(cout "unwrap: fork" nl)
	  (unwrap (k (fork-req))))
	(else
	  (error "~s ~s~n" "unknown scheduler request" request))))
    (v v)))





;------------------
(define bind
  (lambda (r k)
    (case-ans r 
      (mzero) 
      ((a) (k a))
      ((a f) (choice-fork mplus (lambda () (k a))
               (lambdaf@ () (bind (f) k)))))))

(define mplus
  (lambda (r f)
    (case-ans r 
      (f) 
      ((a) (choice a f))
      ((a f0) (choice a
                (lambdaf@ () (choice-fork mplus f0 f)))))))

(define bindi
  (lambda (r k)
    (case-ans r 
      (mzero) 
      ((a) (k a))
      ((a f) (choice-fork interleave (lambda () (k a))
               (lambdaf@ () (bindi (f) k)))))))

(define interleave
  (lambda (r f)
    (case-ans r 
      (f) 
      ((a) (choice a f))
      ((a f0) (choice a
                (lambdaf@ () (choice-fork interleave f f0)))))))

(define prefix                   
  (lambda (n)
    (lambda (r)
      (case-ans r                       
        (quote ())
        ((a) (cons a (quote ())))
        ((a f)
         (cons a
           (cond 
             ((= n 1) (quote ()))
             (else 
               ((prefix (- n 1)) (f))))))))))

(define prefix*
  (lambda (r)
    (case-ans r
      (quote ())
      ((a) (cons a (quote ())))
      ((a f) (cons a (prefix* (f)))))))

(define-syntax run*  
  (syntax-rules ()
    ((_ (x) g0 g ...)
     (map reify 
       (raw-run prefix* (var 'x)
	 (lambda (x) (all g0 g ...)))))))

(define raw-run
  (lambda (filter x f)
    (map (lambda (s) (walk* x s))
      (filter (scheduler (lambda () (bind (unit empty-s) (f x))))))))

(define-syntax run 
  (syntax-rules ()
    ((_ n^ (x) g0 g ...)
     (map reify 
       (let ((n n^))
         (cond
           ((zero? n) (quote ()))
           (else
             (raw-run (prefix n) (var 'x)
               (lambda (x) (all g0 g ...))))))))))


; Another version of run/run* predicates
; Produces an _even_ stream (that is, thunk first)
(define run-to-stream
  (lambda (x f)
    (lambda ()
      (case-ans (f)
	(quote ())
	((a) (cons (walk* x a) (quote ())))
	((a f) (cons (walk* x a) (run-to-stream x f)))))))

(define stream->list
  (lambda (s)
    (let ((s^ (s)))
      (cond
	((null? s^) s^)
	((null? (cdr s^)) s^)
	(else (cons (car s^) (stream->list (cdr s^))))))))

(define-syntax new-run* 
  (syntax-rules ()
    ((_ (x) g0 g ...)
     (map reify
       (stream->list
	 (let ((x (var 'x)))
	   (run-to-stream x
	     (lambdaf@ ()
	       (scheduler (lambdaf@ () (bind (unit empty-s)
					 (all g0 g ...))))))))))))
   
(define stream->list-n
  (lambda (n s)
    (if (zero? n) (quote ())
      (let ((s^ (s)))
	(cond
	  ((null? s^) s^)
	  ((null? (cdr s^)) s^)
	  (else (cons (car s^) (stream->list-n (- n 1) (cdr s^)))))))))


(define-syntax new-run 
  (syntax-rules ()
    ((_ n (x) g0 g ...)
     (map reify
       (stream->list-n n
	 (let ((x (var 'x)))
	   (run-to-stream x
	     (lambdaf@ ()
	       (scheduler (lambdaf@ () (bind (unit empty-s)
					 (all g0 g ...))))))))))))


(define == 
  (lambda (v w)
    (lambdag@ (s)
      (cond
        ((unify v w s) => succeed)
        (else (fail s))))))

;(define succeed (lambdag@ (s) (unit s)))
(define succeed (lambdag@ (s) (begin (yield) (unit s))))

(define ==-check 
  (lambda (v w)
    (lambdag@ (s)
      (cond
        ((unify-check v w s) => succeed)
        (else (fail s))))))

;(define fail (lambdag@ (s) (mzero)))
(define fail (lambdag@ (s) (begin (yield) (mzero))))

(define-syntax fresh 
  (syntax-rules ()
    ((_ (x ...) g0 g ...)
     (lambdag@ (s)
       (let ((x (var 'x)) ...)
         ((all g0 g ...) s))))))

(define-syntax project 
  (syntax-rules ()
    ((_ (x ...) g0 g ...)  
     (lambdag@ (s)
       (let ((x (walk* x s)) ...)
         ((all g0 g ...) s))))))

(define-syntax all
  (syntax-rules ()
    ((_) succeed)
    ((_ g) g)
    ((_ g0 g ...)
     (let ((g^ g0))
       (lambdag@ (s)
         (bind (g^ s)
           (lambdag@ (s) ((all g ...) s))))))))
 
(define-syntax alli
  (syntax-rules ()
    ((_) succeed)
    ((_ g) g)
    ((_ g0 g ...)
     (let ((g^ g0))
       (lambdag@ (s)
         (bindi (g^ s)
           (lambdag@ (s) ((alli g ...) s))))))))

(define-syntax condu
  (syntax-rules ()
    ((_ c ...) (cu chopperu c ...))))

(define-syntax chopperu
  (syntax-rules ()
    ((_ r s) (succeed s))))

(define-syntax cu
  (syntax-rules (else)
    ((_ chopper) fail)
    ((_ chopper (else g ...)) (all g ...))
    ((_ chopper (g0 g ...) c ...)
     (let ((g^ g0))
       (lambdag@ (s)
         (let ((r (intercept-deny-thread-launch (lambda () (g^ s)))))
           ;(display "cu: ") (display r) (newline)
           (case-ans r
             ((cu chopper c ...) s)  
             ((s) ((all g ...) s))
             ((s f) (bind (chopper r s) 
                      (lambdag@ (s)
                        ((all g ...) s)))))))))))

(define-syntax conda
  (syntax-rules ()
    ((_ c ...) (cu choppera c ...))))

(define-syntax choppera
  (syntax-rules ()
    ((_ r s) r)))

(define-syntax conde
  (syntax-rules ()
    ((_ c ...) (ce mplus c ...))))

(define-syntax ce
  (syntax-rules (else)
    ((_ combiner) fail)
    ((_ combiner (else g ...)) (all g ...))
    ((_ combiner (g ...) c ...)
     (let ((g^ (all g ...)))
       (lambdag@ (s)
         (choice-fork combiner (lambda () (g^ s))
           (lambdaf@ () 
             ((ce combiner c ...) s))))))))

(define-syntax condi
  (syntax-rules ()
    ((_ c ...) (ce interleave c ...))))

; just the regular lambda now
(define-syntax lambda-limited 
  (syntax-rules ()
    ((_ n formals g)                                          
      (lambda formals g))))
