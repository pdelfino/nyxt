;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(uiop:define-package :nyxt/reduce-bandwidth-mode
    (:use :common-lisp :nyxt)
  (:documentation "Reduce the internet bandwidth."))
(in-package :nyxt/reduce-bandwidth-mode)

(define-mode reduce-bandwidth-mode ()
  "Reduce the internet bandwidtch enabling `noimage-mode', `noscript-mode', and
`nowebgl-mode'."
  ;(enable-hook 'nyxt/noimage-mode:noimage-mode)
  ;(activate nyxt/noimage-mode:noimage-mode)
  ;(constructor (lambda (mode) (nyxt/noimage-mode:noimage-mode)))
  (nyxt/noimage-mode:noimage-mode) ;it looks like as if it worked, but there is no
                                        ;side effect
  
  )

