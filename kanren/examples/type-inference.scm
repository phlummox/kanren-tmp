; Type Inference
;
; $Id$

(display "Type inference") (newline)

(define parse
  (lambda (e)
    (cond
      [(symbol? e) `(var ,e)]
      [(number? e) `(intc ,e)]
      [(boolean? e) `(boolc ,e)]
      [else (case (car e)
              [(zero?) `(zero? ,(parse (cadr e)))]
              [(sub1) `(sub1 ,(parse (cadr e)))]
              [(+) `(+ ,(parse (cadr e)) ,(parse (caddr e)))]
              [(if) `(if ,(parse (cadr e)) ,(parse (caddr e)) ,(parse (cadddr e)))]
              [(fix) `(fix ,(parse (cadr e)))]
              [(lambda) `(lambda ,(cadr e) ,(parse (caddr e)))]
              [(let) `(let ([,(car (car (cadr e))) ,(parse (cadr (car (cadr e))))])
                        ,(parse (caddr e)))]
              [else `(app ,(parse (car e)) ,(parse (cadr e)))])])))

(define unparse
  (lambda (e)
    (case (car e)
      [(var) (cadr e)]
      [(intc) (cadr e)]
      [(boolc) (cadr e)]
      [(zero?) `(zero? ,(unparse (cadr e)))]
      [(sub1) `(sub1 ,(unparse (cadr e)))]
      [(+) `(+ ,(unparse (cadr e)) ,(unparse (caddr e)))]
      [(if) `(if ,(unparse (cadr e)) ,(unparse (caddr e)) ,(unparse (cadddr e)))]
      [(fix) `(fix ,(unparse (cadr e)))]
      [(lambda) `(lambda (,(car (cadr e))) ,(unparse (caddr e)))]
      [(let) 
       `(let ([,(car (car (cadr e)))
               ,(unparse (cadr (car (cadr e))))])
          ,(unparse (caddr e)))]
      [(app) `(,(unparse (cadr e)) ,(unparse (caddr e)))])))

(define-syntax infer-type
  (syntax-rules ()
    [(_ g term type)
     (cond
       [(solution (g type) (!- g (parse term) type))
        => (lambda (result)
             `(!- ,(cadr (car result)) ,term ,(cadr (cadr result))))]
       [else #f])]))

;;; This is environments.

(define non-generic-match-env
  (fact (g v t) `(non-generic ,v ,t ,g) v t))

(define non-generic-recursive-env
  (relation (g v t)
    (to-show `(non-generic ,_ ,_ ,g) v t)
    (all!! (instantiated g) (env g v t))))

(define env (extend-relation (a1 a2 a3)
              non-generic-match-env non-generic-recursive-env))

(define fix  ;;; this is so that students can see what happens
  (lambda (e)
    (e (lambda (z) ((fix e) z)))))

(define generic-base-env
  (relation (g v targ tresult t)
    (to-show `(generic ,v (--> ,targ ,tresult) ,g) v t)
    (let-inject/no-check ([t^ (targ tresult) (instantiate `(--> ,targ ,tresult))])
      (== t t^))))

(define generic-recursive-env
  (relation (g v t)
    (to-show `(generic ,_ ,_ ,g) v t)
    (all! (env g v t))))

(define generic-env
  (extend-relation (a1 a2 a3) generic-base-env generic-recursive-env))

(define instantiate
  (letrec
      ([instantiate-term
         (lambda (t env)
           (cond
             [(var? t)
              (cond
                [(assq t env)
                 => (lambda (pr)
                      (values (cdr pr) env))]
                [else (let ([new-var (var (var-id t))])
                        (values new-var (cons `(,t . ,new-var) env)))])]
             [(pair? t)
              (let-values (a-t env) (instantiate-term (car t) env)
                (let-values (d-t env) (instantiate-term (cdr t) env)
                  (values (cons a-t d-t) env)))]
             [else (values t env)]))])
    (lambda (t)
      (let-values (ct env) (instantiate-term t '())
        ct))))

(define env (extend-relation (a1 a2 a3) env generic-env))

;;;; This starts the rules

(define int 'int)
(define bool 'bool)

(define var-rel
  (relation (g v t)
    (to-show g `(var ,v) t)
    (all! (env g v t))))

(define int-rel
  (fact (g x) g `(intc ,x) int))

(define bool-rel
  (fact (g x) g `(boolc ,x) bool))

(define zero?-rel
  (relation (g x)
    (to-show g `(zero? ,x) bool)
    (all! (!- g x int))))

(define sub1-rel
  (relation (g x)
    (to-show g `(sub1 ,x) int)
    (all! (!- g x int))))

(define +-rel
  (relation (g x y)
    (to-show g `(+ ,x ,y) int)
    (all!! (!- g x int) (!- g y int))))

(define if-rel
  (relation (g t test conseq alt)
    (to-show g `(if ,test ,conseq ,alt) t)
    (all!! (!- g test bool) (!- g conseq t) (!- g alt t))))

(define lambda-rel
  (relation (g v t body type-v)
    (to-show g `(lambda (,v) ,body) `(--> ,type-v ,t))
    (all! (!- `(non-generic ,v ,type-v ,g) body t))))

(define app-rel
  (relation (g t rand rator)
    (to-show g `(app ,rator ,rand) t)
    (let-lv (t-rand)
      (all!! (!- g rator `(--> ,t-rand ,t)) (!- g rand t-rand)))))

(define fix-rel
  (relation (g rand t)
    (to-show g `(fix ,rand) t)
    (all! (!- g rand `(--> ,t ,t)))))

(define polylet-rel
  (relation (g v rand body t)
    (to-show g `(let ([,v ,rand]) ,body) t)
    (let-lv (t-rand)
      (all!!
        (!- g rand t-rand)
        (!- `(generic ,v ,t-rand ,g) body t)))))

(define !-
  (extend-relation (a1 a2 a3)
    var-rel int-rel bool-rel zero?-rel sub1-rel +-rel 
    if-rel lambda-rel app-rel fix-rel polylet-rel))

(test-check 'test-!-1
  (and
    (equal?
      (solution () (exists (g) (!- g '(intc 17) int)))
      '())
    (equal?
      (solution (?) (exists (g) (!- g '(intc 17) ?)))
      '((?.0 int))))
  #t)

(test-check 'arithmetic-primitives
  (solution (?) (exists (g)  (!- g '(zero? (intc 24)) ?)))
  '((?.0 bool)))

(test-check 'test-!-sub1
  (solution (?) (exists (g) (!- g '(zero? (sub1 (intc 24))) ?)))
  '((?.0 bool)))

(test-check 'test-!-+
  (solution (?)
    (exists (g)
      (!- g '(zero? (sub1 (+ (intc 18) (+ (intc 24) (intc 50))))) ?)))
  '((?.0 bool)))

(test-check 'test-!-2
  (and
    (equal?
      (solution (?) (exists (g) (!- g '(zero? (intc 24)) ?)))
      '((?.0 bool)))
    (equal?
      (solution (?) (exists (g) (!- g '(zero? (+ (intc 24) (intc 50))) ?)))
      '((?.0 bool)))
    (equal?
      (solution (?)
        (exists (g)
          (!- g '(zero? (sub1 (+ (intc 18) (+ (intc 24) (intc 50))))) ?)))
      '((?.0 bool))))
  #t)

(test-check 'test-!-3
  (solution (?) (!- '() '(if (zero? (intc 24)) (intc 3) (intc 4)) ?))
  '((?.0 int)))

(test-check 'if-expressions
  (solution (?)
    (exists (g) (!- g '(if (zero? (intc 24)) (zero? (intc 3)) (zero? (intc 4))) ?)))
  '((?.0 bool)))

(test-check 'variables
  (and
    (equal?
      (solution (?)
        (exists (g)
          (env `(non-generic b int (non-generic a bool ,g)) 'a ?)))
      '((?.0 bool)))
    (equal?
      (solution (?)
        (exists (g)
          (!- `(non-generic a int ,g) '(zero? (var a)) ?)))
      '((?.0 bool)))
    (equal?
      (solution (?)
        (exists (g)
          (!- `(non-generic b bool (non-generic a int ,g))
            '(zero? (var a))
            ?)))
      '((?.0 bool))))
  #t)

(test-check 'variables-4a
  (solution (?)
    (exists (g)
      (!- `(non-generic b bool (non-generic a int ,g))
        '(lambda (x) (+ (var x) (intc 5)))
        ?)))
  '((?.0 (--> int int))))

(test-check 'variables-4b
  (solution (?)
    (exists (g)
      (!- `(non-generic b bool (non-generic a int ,g))
        '(lambda (x) (+ (var x) (var a)))
        ?)))
  '((?.0 (--> int int))))

(test-check 'variables-4c
  (solution (?)
    (exists (g) 
      (!- g '(lambda (a) (lambda (x) (+ (var x) (var a)))) ?)))
  '((?.0 (--> int (--> int int)))))

(test-check 'everything-but-polymorphic-let
  (solution (?)
    (exists (g)
      (!- g (parse
              '(lambda (f)
                 (lambda (x)
                   ((f x) x))))
        ?)))
  '((?.0 (-->
           (--> type-v.0 (--> type-v.0 t.0))
           (--> type-v.0 t.0)))))

(test-check 'everything-but-polymorphic-let
  (solution (?)
    (exists (g)
      (!- g
        (parse
          '((fix (lambda (sum)
                   (lambda (n)
                     (if (zero? n)
                         0
                         (+ n (sum (sub1 n)))))))
            10))
        ?)))
  '((?.0 int)))

(test-check 'everything-but-polymorphic-let
  (solution (?)
    (exists (g)
      (!- g
        (parse
          '((fix (lambda (sum)
                   (lambda (n)
                     (+ n (sum (sub1 n))))))
            10))
        ?)))
  '((?.0 int)))

(test-check 'everything-but-polymorphic-let
  (solution (?)
    (exists (g)
      (!- g
        (parse '((lambda (f)
                   (if (f (zero? 5))
                       (+ (f 4) 8)
                       (+ (f 3) 7)))
                 (lambda (x) x)))
        ?)))
  #f)

(test-check 'polymorphic-let
  (solution (?)
    (exists (g)
      (!- g
        (parse
          '(let ([f (lambda (x) x)])
             (if (f (zero? 5))
                 (+ (f 4) 8)
                 (+ (f 3) 7))))
        ?)))
  '((?.0 int)))

(test-check 'with-robust-syntax
  (solution (?)
    (exists (g)
      (!- g
        '(app
           (fix
             (lambda (sum)
               (lambda (n)
                 (if (if (zero? (var n)) (boolc #t) (boolc #f))
                     (intc 0)
                     (+ (var n) (app (var sum) (sub1 (var n))))))))
           (intc 10))
        ?)))
  '((?.0 int)))

(test-check 'with-robust-syntax-but-long-jumps/poly-let
  (solution (?)
    (exists (g)
      (!- g
        '(let ([f (lambda (x) (var x))])
           (if (app (var f) (zero? (intc 5)))
               (+ (app (var f) (intc 4)) (intc 8))
               (+ (app (var f) (intc 3)) (intc 7))))
        ?)))
  '((?.0 int)))

(test-check 'type-habitation
  (and
    (equal?
      (solution (g ?)
        (!- g ? '(--> int int)))
      '((g.0 (non-generic v.0 (--> int int) g.1)) (?.0 (var v.0))))
    (equal?
      (solution (la f b)
        (exists (g)
          (!- g `(,la (,f) ,b) '(--> int int))))
      '((la.0 lambda) (f.0 v.0) (b.0 (var v.0))))
    (equal?
      (solution (g h r q z y t)
        (!- g `(,h ,r (,q ,z ,y)) t))
      '((g.0 (non-generic v.0 int g.1))
        (h.0 +)
        (r.0 (var v.0))
        (q.0 +)
        (z.0 (var v.0))
        (y.0 (var v.0))
        (t.0 int)))
    (equal?
      (solution (h r q z y t u v)
        (exists (g)
          (!- g `(,h ,r (,q ,z ,y)) `(,t ,u ,v))))
      '((h.0 lambda)
        (r.0 (v.0))
        (q.0 +)
        (z.0 (var v.0))
        (y.0 (var v.0))
        (t.0 -->)
        (u.0 int)
        (v.1 int))))
  #t)

;;; long cuts
;;; No cuts are needed any more
; (define !-generator
;   (lambda (long-cut)
;     (letrec
;       ([!- (extend-relation (a1 a2 a3)
;              (relation (g v t)
;                (to-show g `(var ,v) t)
;                (all long-cut (env g v t)))
;              (fact (g x) g `(intc ,x) int)
;              (fact (g x) g `(boolc ,x) bool)
;              (relation (g x)
;                (to-show g `(zero? ,x) bool)
;                (all long-cut (!- g x int)))
;              (relation (g x)
;                (to-show g `(sub1 ,x) int)
;                (all long-cut (!- g x int)))
;              (relation (g x y)
;                (to-show g `(+ ,x ,y) int)
;                (all long-cut (all! (!- g x int) (!- g y int))))
;              (relation (g t test conseq alt)
;                (to-show g `(if ,test ,conseq ,alt) t)
;                (all long-cut
; 		 (all! (!- g test bool) (!- g conseq t) (!- g alt t))))
;              (relation (g v t body type-v)
;                (to-show g `(lambda (,v) ,body) `(--> ,type-v ,t))
;                (all long-cut (!- `(non-generic ,v ,type-v ,g) body t)))
;              (relation (g t rand rator)
;                (to-show g `(app ,rator ,rand) t)
;                (exists (t-rand)
;                  (all long-cut
; 		   (all!
;                      (!- g rator `(--> ,t-rand ,t))
;                      (!- g rand t-rand)))))
;              (relation (g rand t)
;                (to-show g `(fix ,rand) t)
;                (all long-cut (!- g rand `(--> ,t ,t))))
;              (relation (g v rand body t)
;                (to-show g `(let ([,v ,rand]) ,body) t)
;                (exists (t-rand)
;                  (all long-cut
; 		   (all!
;                      (!- g rand t-rand)
;                      (!- `(generic ,v ,t-rand ,g) body t))))))])
;       !-)))
;
; (define !-
;   (relation/cut cut (g exp t)
;     (to-show g exp t)
;     ((!-generator cut) g exp t)))


; (relation-cond vars clause ...)
; clause::= ((local-var...) (condition ...) (conseq ...))

(define-syntax relation-cond
  (syntax-rules ()
    ((_ (global-var ...) clause0 clause1 ...)
      (lambda (global-var ...)
	(lambda@ (sk fk subst)
	  (relation-cond-clause (sk fk subst)
	    clause0 clause1 ...))))))

(define-syntax relation-cond-clause
  (syntax-rules ()
    ((_ (sk fk subst)) (fk)) ; no more choices: fail
    ((_ (sk fk subst) 
       (local-vars (condition ...) conseq)
       clause ...)
      (let-lv local-vars			; a bit sloppy, need exists...
	(printf "running ~a~n" '(condition ...))
	(@ (all!! condition ...)
	; sk
	  (lambda@ (fk-ign)
	    (@ conseq sk fk))
	; fk
	  (lambda () (relation-cond-clause (sk fk subst) clause ...))
	  subst)))))


; (define !-
;     (letrec
;       ([!- (extend-relation (a1 a2 a3)
;              (relation (g v t)
;                (to-show g `(var ,v) t)
;                (all long-cut (env g v t)))
;              (fact (g x) g `(intc ,x) int)
;              (fact (g x) g `(boolc ,x) bool)
;              (relation (g x)
;                (to-show g `(zero? ,x) bool)
;                (all long-cut (!- g x int)))
;              (relation (g x)
;                (to-show g `(sub1 ,x) int)
;                (all long-cut (!- g x int)))
;              (relation (g x y)
;                (to-show g `(+ ,x ,y) int)
;                (all long-cut (all! (!- g x int) (!- g y int))))
;              (relation (g t test conseq alt)
;                (to-show g `(if ,test ,conseq ,alt) t)
;                (all long-cut
; 		 (all! (!- g test bool) (!- g conseq t) (!- g alt t))))
;              (relation (g v t body type-v)
;                (to-show g `(lambda (,v) ,body) `(--> ,type-v ,t))
;                (all long-cut (!- `(non-generic ,v ,type-v ,g) body t)))
;              (relation (g t rand rator)
;                (to-show g `(app ,rator ,rand) t)
;                (exists (t-rand)
;                  (all long-cut
; 		   (all!
;                      (!- g rator `(--> ,t-rand ,t))
;                      (!- g rand t-rand)))))
;              (relation (g rand t)
;                (to-show g `(fix ,rand) t)
;                (all long-cut (!- g rand `(--> ,t ,t))))
;              (relation (g v rand body t)
;                (to-show g `(let ([,v ,rand]) ,body) t)
;                (exists (t-rand)
;                  (all long-cut
; 		   (all!
;                      (!- g rand t-rand)
;                      (!- `(generic ,v ,t-rand ,g) body t))))))])
;       !-)))

(define !-
  (relation-cond (g exp t)
    ((v) ((== exp `(var ,v)))
      (env g v t))
    (() ((== exp `(intc ,_)) (== t int)) succeed)
    (() ((== exp `(boolc ,_)) (== t bool)) succeed)
    ((x) ((== exp `(zero? ,x)) (== t bool))
      (!- g x int))
    ((x) ((== exp `(sub1 ,x)) (== t int))
      (!- g x int))
    ((x y) ((== exp `(+ ,x ,y)) (== t int))
      (all!! (!- g x int) (!- g y int)))
    ((test conseq alt) ((== exp `(if ,test ,conseq ,alt)))
      (all!! (!- g test bool) (!- g conseq t) (!- g alt t)))
    ((body type-v v t1) ((== exp `(lambda (,v) ,body)) 
			 (== t `(--> ,type-v ,t1)))
      (!- `(non-generic ,v ,type-v ,g) body t1))
    ((rand rator) ((== exp `(app ,rator ,rand)))
      (exists (t-rand)
	(all!!
	  (!- g rator `(--> ,t-rand ,t))
	  (!- g rand t-rand))))
    ((rand) ((== exp `(fix ,rand)))
      (!- g rand `(--> ,t ,t)))
    ((v rand body) ((== exp `(let ([,v ,rand]) ,body)))
      (exists (t-rand)
	(all!!
	  (!- g rand t-rand)
	  (!- `(generic ,v ,t-rand ,g) body t))))))

'(define !-
  (relation-cond (g exp t)
    ((v) ((== exp `(var ,v)))
      succeed)))

(pretty-print (expand '(relation-cond (g exp t)
    ((v) ((== exp `(var ,v)))
      succeed))))

(test-check 'with-robust-syntax-but-long-jumps/poly-let
  (solution (?)
    (exists (g)
      (!- g
        '(let ([f (lambda (x) (var x))])
           (if (app (var f) (zero? (intc 5)))
               (+ (app (var f) (intc 4)) (intc 8))
               (+ (app (var f) (intc 3)) (intc 7))))
        ?)))
  '((?.0 int)))


(define invertible-binary-function->ternary-relation
  (lambda (op inverted-op)
    (extend-relation (a1 a2 a3)
      (relation (x y z)
        (to-show x y z)
        (all (fails (instantiated z))
          (let-inject ([z^ (x y) (op x y)])
            (== z z^))))
      (relation (x y z)
        (to-show x y z)
        (all (fails (instantiated y))
          (let-inject ([y^ (z x) (inverted-op z x)])
            (== y y^))))
      (relation (x y z)
        (to-show x y z)
        (all (fails (instantiated x))
          (let-inject ([x^ (z y) (inverted-op z y)])
            (== x x^))))
      (relation (x y z)
        (to-show x y z)
        (let-inject ([z^ (x y) (op x y)])
          (== z z^))))))

(define ++ (invertible-binary-function->ternary-relation + -))
(define -- (invertible-binary-function->ternary-relation - +))
(define ** (invertible-binary-function->ternary-relation * /))
(define // (invertible-binary-function->ternary-relation / *))

(test-check 'test-instantiated-1
  (and
    (equal?
      (solution (x) (++ x 16.0 8))
      '((x.0 -8.0)))
    (equal?
      (solution (x) (++ 10 16.0 x))
      '((x.0 26.0)))
    (equal?
      (solution (x) (-- 10 x 3))
      '((x.0 13))))
  #t)

(define symbol->lnum
  (lambda (sym)
    (map char->integer (string->list (symbol->string sym)))))

(define lnum->symbol
  (lambda (lnums)
    (string->symbol (list->string (map integer->char lnums)))))

(define invertible-unary-function->binary-relation
  (lambda (op inverted-op)
    (extend-relation (a1 a2)
      (relation (x y)
        (to-show x y)
        (all (fails (instantiated y))
          (let-inject ([y^ (x) (op x)])
            (== y y^))))
      (relation (x y)
        (to-show x y)
        (all (fails (instantiated x))
          (let-inject ([x^ (y) (inverted-op y)])
            (== x x^))))
      (relation (x y)
        (to-show x y)
        (begin
          (pretty-print "Third rule")
          (let-inject ([y^ (x) (op x)])
            (== y y^)))))))

(define name
  (invertible-unary-function->binary-relation symbol->lnum lnum->symbol))

(test-check 'test-instantiated-2
  (and
    (equal?
      (solution (x) (name 'sleep x))
      '((x.0 (115 108 101 101 112))))
    (equal?
      (solution (x) (name x '(115 108 101 101 112)))
      '((x.0 sleep))))
  #t)