;;; Copyright (c) 1993 by Olin Shivers.

;;; Syntax for defining record types.
;;; This implementation works with the Scheme48 system --
;;; or any Scheme that uses Clinger's "explicit renaming"
;;; macro system.
;;;
;;; (define-record name . field&method-specs)
;;;
;;; A field-spec is one of the following:
;;;     field		; Initialised field
;;;     (field [default])	; Defaulted field.
;;; An initialised field has its initial value passed as an argument to
;;; the the record maker procedure. A defaulted field takes its value from
;;; the the DEFAULT expression. If a DEFAULT expression is not given, then
;;; the defaulted field's initial value is undefined.
;;; 
;;; Example:
;;; (define-record employee
;;;     name
;;;     id
;;;     (salary 10000)
;;;     (department)	; Initial value undefined.
;;;     sex
;;;     married?)
;;; 
;;; Defines the following:
;;; - A maker procedure:
;;;   (make-employee "John Smith" 742931 'male #f)
;;;   MAKE-EMPLOYEE takes one argument for each initialised field.
;;; 
;;; - Accessor procedures:
;;;   (employee:name emp)
;;;   (employee:id emp)
;;;   (employee:salary emp)
;;;   (employee:department emp)
;;;   (employee:sex emp)
;;;   (employee:married? emp)
;;; 
;;; - Setter procedures:
;;;   (set-employee:name emp "Janet Q. Random")
;;;   (set-employee:id emp 8271)
;;;   (set-employee:salary emp 20000)
;;;   (set-employee:department emp "Vaporware")
;;;   (set-employee:sex emp 'female)
;;;   (set-employee:married? emp #t)
;;; 
;;; - A type predicate:
;;;   (employee? x)
;;; 
;;; - The record type descriptor:
;;;     type/employee

;;; Method specs are of the form
;;; ((method self var ...) body ...)
;;; The only supported method is DISCLOSE, which is used by the S48
;;; structure printer. E.g.,
;;;   (define-record ship
;;;     x
;;;     y
;;;     name
;;;     ((disclose self) (list (ship:name self))))
;;; will cause (make-ship 10 20 "Valdez") to print as
;;;   #{ship "Valdez"}

(import-for-syntax (only chicken receive))

(define-syntax define-record
  (lambda (form rename compare)
    (receive (field-specs method-specs)
	     ;; Partition the field and method specs by form.
	     (let lp ((specs (reverse (cddr form)))
		      (fspecs '())
		      (mspecs '()))
	       (if (pair? specs)
		   (let ((spec (car specs))
			 (specs (cdr specs)))
		     (if (and (pair? spec) (pair? (car spec)))
			 (if (eq? (caar spec) 'disclose)
			     (lp specs fspecs (cons spec mspecs))
			     (error "Unsupported method in define-record." spec))
			 (lp specs (cons spec fspecs) mspecs)))
		   (values fspecs mspecs)))

      (let* ((name (cadr form))
	     (s->s symbol->string)
	     (s-conc (lambda args (string->symbol (apply string-append args))))
	     (spec-name (lambda (s) (if (pair? s) (car s) s)))
	     (filter (lambda (pred lst)
		       (let f ((lst lst))
			 (if (pair? lst)
			     (let ((tail (f (cdr lst))))
			       (if (pred (car lst)) (cons (car lst) tail) tail))
			     '()))))
	     (gensym (let ((j 0))
		       (lambda (s) (set! j (+ j 1))
			       (s-conc s (number->string j)))))

	     (field-name (lambda (field-name)
			   (s-conc (s->s name) ":" (s->s field-name))))
	     (set-name (lambda (field-name)
			 (s-conc "set-" (s->s name) ":" (s->s field-name))))
	     (pred-name (s-conc (s->s name) "?"))
	     (maker-name (s-conc "make-" (s->s name)))
	     (type-name (s-conc "type/" (s->s name)))

	     (fields (map spec-name field-specs))
	     (param-fields (filter symbol? field-specs)) ; Args to maker proc.
	     (default-field-specs (filter (lambda (fs) (and (pair? fs)
							    (pair? (cdr fs))))
					  field-specs))
	     (default-exps (map cadr default-field-specs))
	     (param-vars (map (lambda (fs) (rename (gensym "field")))
			      param-fields))

	     (maker (rename 'maker))
	     (%make-record-type   (rename 'make-record-type))
	     (%record-constructor (rename 'record-constructor))
	     (%record-predicate	  (rename 'record-predicate))
	     (%record-accessor	  (rename 'record-accessor))
	     (%record-modifier	  (rename 'record-modifier))
	     (%unspecified	  (rename 'void))
	     (%define		  (rename 'define))
	     (%let		  (rename 'let))
	     (%lambda		  (rename 'lambda))
	     (%begin		  (rename 'begin)))

	`(,%begin
	  (,%define ,type-name
	    (,%make-record-type ,(s->s name) ',fields))

	  ;; Maker proc (MAKE-EMPLOYEE name id-number sex married?)
	  (,%define ,maker-name
	    ,(if (null? default-field-specs)
		 ;; Gratuitous optimisation:
		 `(,%record-constructor ,type-name ',param-fields)
	      
		 ;; Full-blown form.
		 `(,%let ((,maker (,%record-constructor
				   ,type-name
				   ',(append param-fields
					     (map spec-name
						  default-field-specs)))))
			 (,%lambda ,param-vars
		           (,maker ,@param-vars ,@default-exps)))))

	  ;; Type predicate (EMPLOYEE? x)
	  (,%define ,pred-name (,%record-predicate ,type-name))
       
	  ;; Accessors (EMPLOYEE:NAME emp), ...
	  ,@(map (lambda (spec)
		   `(,%define ,(field-name (spec-name spec))
		      (,%record-accessor ,type-name ',(spec-name spec))))
		 field-specs)

	  ;; Setters (SET-EMPLOYEE:NAME emp name), ...
	  ,@(map (lambda (spec)
		   `(,%define ,(set-name (spec-name spec))
		      (,%record-modifier ,type-name ',(spec-name spec))))
		 field-specs)

	  )))))
