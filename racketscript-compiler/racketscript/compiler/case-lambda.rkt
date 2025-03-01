#lang racket

(require (for-syntax syntax/parse)
         syntax/parse
         syntax/stx)

(provide s-case-lambda
         module-replace-case-lambda)

(define (module-replace-case-lambda mod)
  (syntax-parse mod
    #:literal-sets ((kernel-literals))
    [(module id path (#%plain-module-begin form ...))
     (expand-case-lambda mod)]))

(define (expand-case-lambda e)
  (syntax-parse (syntax-disarm e #f)
    #:literal-sets ((kernel-literals))
    [(case-lambda (formals body ...+) ...)
     #:with (new-clauses ...) (stx-map (λ (f b)
                                         #`(#,f #,@(stx-map expand-case-lambda b)))
                                       #`(formals ...)
                                       #`((body ...) ...))
     #`(case-lambda new-clauses ...)]
    [(module name:id path:expr (#%plain-module-begin form ...))
     (expand #`(module name path
                 (#%plain-module-begin
                  (#%require (rename racketscript/compiler/case-lambda
                                     case-lambda
                                     s-case-lambda))
                  #,@(stx-map expand-case-lambda #'(form ...)))))]
    [(#%expression v)1
     #`(#%expression #,(expand-case-lambda #'v))]
    [(begin0 e0 e ...)
     #`(begin0 #,@(stx-map expand-case-lambda #'(e0 e ...)))]
    [(begin e ...)
     #`(begin #,@(stx-map expand-case-lambda #'(e ...)))]
    [(#%top . x) #`(#%top . #,(expand-case-lambda #'x))]
    [(quote e) #'(quote e)]
    [(~or (~literal module)
          (~literal module*)
          (~literal #%require)
          (~literal quote)) e]
    [(if e0 e1 e2)
     #`(if #,(expand-case-lambda #'e0)
           #,(expand-case-lambda #'e1)
           #,(expand-case-lambda #'e2))]
    [(#%plain-lambda xs . body)
     #`(#%plain-lambda xs . #,(stx-map expand-case-lambda #'body))]
    [(let-values ([xs es] ...) b ...)
     #:with (es* ...) (stx-map expand-case-lambda #'(es ...))
     #`(let-values ([xs es*] ...)
         #,@(stx-map expand-case-lambda #'(b ...)))]
    [(letrec-values ([xs es] ...) b ...)
     #:with (es* ...) (stx-map expand-case-lambda #'(es ...))
     #`(let-values ([xs es*] ...)
         #,@(stx-map expand-case-lambda #'(b ...)))]
    [(define-values (id ...) b)
     #`(define-values (id ...) #,(expand-case-lambda #'b))]
    [(e ...)
     (stx-map expand-case-lambda #'(e ...))]
    [_ e]))

;; s-case-lambda : Syntax -> Syntax
;; Transforms case-lambda to plain-lambda using nested if-else
(define-syntax (s-case-lambda stx)
  (define-syntax-class formals
    #:description "formal arguments"
    (pattern (~or var:id
                  (v0:id ...)
                  (v1:id ...+ . v1*:id))))
  (define-syntax-class clause
    #:description "A single case-lambda clause"
    (pattern (f:formals body:expr ...+)))

  ;; formals-check : Syntax Syntax:Formals -> stx
  ;; Produce expression to check if arguments given at `args`
  ;; from the driver lambda is valid for current case
  (define (formals-check stx)
    (syntax-parse stx
      [(args:expr var:id) #'(list? args)]
      [(args:expr (var:id ...))
       #:with len (datum->syntax stx (length (syntax-e #'(var ...))))
       #'(equal? (length args) len)]
      [(args:expr (var:id ...+ . vtl:id))
       #:with len (datum->syntax stx (length (syntax-e #'(var ...))))
       #'(>= (length args) len)]))

  ;; transform : Syntax -> Syntax
  ;; Transforms each clause of case-lambda to nested if-else
  ;; expression
  (define (transform stx)
    (syntax-parse stx
      [(args:expr) #'(error "No match for case-lambda")]
      [(args:expr (fs:formals body:expr ...+) c:clause ...)
       #:with check-expr (formals-check #'(args fs))
       #:with rest-clauses (transform #'(args c ...))
       #'(if check-expr
             (apply (λ fs body ...) args)
             rest-clauses)]))

  (syntax-parse stx
    #:literals (λ)
    [(c-λ (fs:formals body:expr ...+) ...)
     ;#:with args (gensym 'args)
     #:with body* (transform #'(args (fs body ...) ...))
     #'(λ args body*)]))

(module+ test
  (require rackunit)

  (define (case-lambda-inside? stx)
    (syntax-parse stx
      [((~literal case-lambda) c ...) #t]
      [(f ...) (ormap case-lambda-inside? (syntax-e #'(f ...)))]
      [v #f]))
  (check-false (case-lambda-inside? #'(+ 1 3 4)))
  (check-false (case-lambda-inside? #'(if #t (λ (x) x) #f)))
  (check-true (case-lambda-inside? #'(if #t
                                         (case-lambda
                                           [(a) a]
                                           [(a b) (+ a b)]))))

  (define lam1
    (s-case-lambda
     [(a b c) (* a b c)]
     [(a b) (+ a b)]))

  (check-equal? (lam1 8 2 3) (* 8 2 3) "match with first case")
  (check-equal? (lam1 3 4) (+ 3 4) "match with second case")
  (check-exn exn:fail? (λ () (lam1 3 4 5 6)) "no matching clause")

  (define lam2
    (s-case-lambda
     [() "duh"]
     [(a b c) (* a b c)]
     [(a b) (+ a b)]
     [v (apply / v)]))

  (check-equal? (lam2) "duh" "case without any arguments")
  (check-equal? (lam2 8 2 3) (* 8 2 3) "match with first case")
  (check-equal? (lam2 3 4) (+ 3 4) "match with second case")
  (check-equal? (lam2 3 4 5 6) (/ 3 4 5 6) "match the variable arg clause")

  (define lam3
    (s-case-lambda
     [() "duh"]
     [(a b c) (* a b c)]
     [(a b) (+ a b)]
     [(a b c . d) (+ a b c (apply * d))]
     [v (apply / v)]))

  (check-equal? (lam3) "duh" "case without any arguments")
  (check-equal? (lam3 8 2 3) (* 8 2 3) "match with first case")
  (check-equal? (lam3 3 4) (+ 3 4) "match with second case")
  (check-equal? (lam3 3 4 5 6) (+ 3 4 5 6) "match the variable arg clause")
  (check-equal? (lam3 3 4 5 6 7 8 9) (+ 3 4 5 (* 6 7 8 9))
                "match the variable arg clause")

  (check-equal?
   (syntax->datum
    (module-replace-case-lambda
     (expand
      #'(module foo '#%kernel
          (if (add1 0)
              (case-lambda
                [(a b c) (* a b c)]
                [(a b) (+ a b)])
              (begin
                (let-values ([(lam) (case-lambda
                                      [(a b c) (* a b c)]
                                      [(a b) (+ a b)])])
                  lam)))))))
   (syntax->datum
    (expand
     #`(module foo '#%kernel
         (#%plain-module-begin
          (#%require
           (rename racketscript/compiler/case-lambda case-lambda s-case-lambda))
          (if (add1 0)
              (case-lambda
                [(a b c) (* a b c)]
                [(a b) (+ a b)])
              (begin
                (let-values ([(lam) (case-lambda
                                      [(a b c) (* a b c)]
                                      [(a b) (+ a b)])])
                  lam))))))))

  (define define-user-mod
    (expand
     #'(module test-case-lambda-define '#%kernel
         (#%require (only racket/base define displayln))
         (define (add a [b 10])
           (+ a b))
         (displayln (add 1))
         (displayln (add 1 2)))))

  (define define-user-mod-c (module-replace-case-lambda define-user-mod))

  ;; Check if original code had case-lambda, but new one didn't
  (check-true (case-lambda-inside? define-user-mod))
  (check-false (case-lambda-inside? define-user-mod-c))

  (let ([stdout (open-output-string)])
    (parameterize ([current-namespace (make-base-namespace)]
                   [current-output-port stdout])
      (eval-syntax define-user-mod-c)
      (eval `(require 'test-case-lambda-define)))
    (check-equal? (get-output-string stdout) "11\n3\n")))
