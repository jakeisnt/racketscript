#lang racket/base

(define h1 #hasheq((1 . 2) (3 . 4)))
(define h2 #hasheq((color . red) (shape . circle)))
(define h3 #hasheq(((a b c) . d) (g . (e f g))))
(define h4 #hasheq(("name" . "Vishesh") ("location" . "Boston")))

(displayln (hasheq 1 2 3 4))

(displayln "equality")

(list? h1)

(hash? h1)
(hash? h2)
(hash? h3)
(hash? h4)
(hash? 'not-a-hash)
(hash-equal? h1)
(hash-eqv? h1)
(hash-eq? h1)
(hash-equal? h2)
(hash-eqv? h2)
(hash-eq? h2)

(define h (make-hasheq (list (cons 1 2) (cons 3 4))))
(define wh (make-weak-hasheq (list (cons 1 2) (cons 3 4))))
(define imh (make-immutable-hasheq (list (cons 1 2) (cons 3 4))))

(displayln h)
(hash? h)
(hash-equal? h)
(hash-eqv? h)
(hash-eq? h)

;; make-weak-hashX is not Racket weak hash
;(displayln wh)
(hash? wh)
(hash-equal? wh)
(hash-eqv? wh)
(hash-eq? wh)

(displayln imh)
(hash? imh)
(hash-equal? imh)
(hash-eqv? imh)
(hash-eq? imh)

(displayln "numbers")
(equal? (hash-ref h1 1) 2)
(equal? (hash-ref h1 3) 4)

(displayln "symbols")
(equal? (hash-ref h2 'color) 'red)
(equal? (hash-ref h2 'shape) 'circle)

(displayln "pairs")
(equal? (hash-ref h3 '(a b c) #f) #f)
(equal? (hash-ref h3 'g) '(e f g))

(displayln "strings")
(equal? (hash-ref h4 "name") "Vishesh")
(equal? (hash-ref h4 "location") "Boston")
(equal? (hash-ref h4 "age" #f) #f)

(struct posn (x y) #:transparent)

(displayln "hash-set")
(equal? (hash-set h1 5 6) #hasheq((1 . 2) (3 . 4) (5 . 6)))
(equal? (hash-set h1 5 6) #hasheqv((1 . 2) (3 . 4) (5 . 6)))
(equal? (hash-set h1 5 6) #hash((1 . 2) (3 . 4) (5 . 6)))
(equal? (hash-set h1 '(1 4) 'foobar)
        #hasheq(((1 4) . 'foobar) (1 . 2) (3 . 4) (5 . 6)))
(define sl0 '(a b c))
(equal? (hash-ref (hash-set h3 sl0 'new-value) '(a b c) #f) #f)
(equal? (hash-ref (hash-set h3 sl0 'new-value) sl0 #f) sl0)

(displayln "structs")
(define p1 (posn 2 4))
(define p2 (posn 2 4))

(equal? (hash-set h1 (posn 2 4) (list (posn 0 0) 'origin))
        (hash-set h1 (posn 2 4) (list (posn 0 0) 'origin)))
(equal? (hash-set h1 (posn 2 4) (list (posn 0 0) 'origin))
        (hash-set h1 (posn 2 4) (list (posn 0 0) 'not-origin)))

(equal? (hash-ref (hash-set h1 p1 (list (posn 0 0) 'origin)) p2 #f) #f)
(equal? (hash-ref (hash-set h1 p1 (list (posn 0 0) 'origin)) p1)
        (list (posn 0 0) 'origin))

;; check eq-ness
;; hasheq should return 1
;; Racket documentation promises `eq?` for characters with
;; scalar values in the range 0 to 255
(hash-ref (hasheq (integer->char 255) 1)
          (integer->char 255)
          2)
;; for chars > 255, eq behavior is actually undefined??
;; eg, the following test returns 2 for < racket 8, but 1 for racket 8+ (chez)
;; so skip the test
;; see: https://groups.google.com/g/racket-users/c/LFFV-xNq1SU/m/s6eoC35qAgAJ
#;(hash-ref (hasheq (integer->char 955) 1)
          (integer->char 955)
          2)
