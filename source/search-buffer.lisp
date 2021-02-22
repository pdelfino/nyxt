;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt/web-mode)

(define-parenscript query-buffer (&key query (case-sensitive-p nil))
  (defvar *identifier* 0)
  (defvar *matches* (array))
  (defvar *nodes* (ps:new (-Object)))
  (defvar *node-replacements* (array))

  (defun qs (context selector)
    "Alias of document.querySelector"
    (ps:chain context (query-selector selector)))

  (defun qsa (context selector)
    "Alias of document.querySelectorAll"
    (ps:chain context (query-selector-all selector)))

  (defun add-stylesheet ()
    (unless (qs document "#nyxt-stylesheet")
      (ps:try
       (ps:let* ((style-element (ps:chain document (create-element "style")))
                 (box-style (ps:lisp (box-style (current-web-mode))))
                 (highlighted-style (ps:lisp (highlighted-box-style (current-web-mode)))))
         (setf (ps:@ style-element id) "nyxt-stylesheet")
         (ps:chain document head (append-child style-element))
         (ps:chain style-element sheet (insert-rule box-style 0))
         (ps:chain style-element sheet (insert-rule highlighted-style 1)))
       (:catch (error)))))

  (defun create-match-object (body identifier)
    (ps:create "type" "match" "identifier" identifier "body" body))

  (defun create-match-span (body identifier)
    (ps:let* ((el (ps:chain document (create-element "span"))))
      (setf (ps:@ el class-name) "nyxt-hint")
      (setf (ps:@ el text-content) body)
      (setf (ps:@ el id) (+ "nyxt-hint-" identifier))
      el))

  (defun get-substring (string query index)
    "Return the substring and preceding/trailing text for a given
     index."
    (let* ((character-preview-count 40))
           (ps:chain string
                     (substring (- index character-preview-count)
                                (+ index (length query) character-preview-count)))))

  (defun get-substring-indices (query string)
    "Get the indices of all matching substrings."
    (let ((rgx (ps:new (|RegExp| query (if (ps:lisp case-sensitive-p) "" "i"))))
          (index (- (length query))))
      (loop with subindex = 0
            until (= subindex -1)
            do (setf subindex (ps:chain string (search rgx)))
               (setf string (ps:chain string (substring (+ subindex (length query)))))
               (setf index (+ index subindex (length query)))
            when (not (= subindex -1))
              collect index)))

  (defun matches-from-node (node query)
    "Return all of substrings that match the search-string."
    (when (= (ps:chain (typeof (ps:@ node node-value))) "string")
      (let* ((node-text (ps:@ node text-content))
             (substring-indices (get-substring-indices query node-text))
             (node-identifier (incf (ps:chain *nodes* identifier)))
             (new-node (ps:chain document (create-element "span"))))
        (setf (ps:@ new-node class-name) "nyxt-search-node")
        (setf (ps:@ new-node id) node-identifier)
        (setf (aref *nodes* node-identifier) node)
        (when (> (length substring-indices) 0)
          (loop for index in substring-indices
                with last-index = 0
                do (incf *identifier*)
                   (ps:chain new-node (append-child (ps:chain document (create-text-node (ps:chain node-text (substring last-index index))))))
                   (ps:chain new-node (append-child (create-match-span (ps:chain node-text (substring index (+ index (length query)))) *identifier*)))
                   (setf last-index (+ (length query) index))
                   (ps:chain *matches* (push (create-match-object (get-substring node-text query index) *identifier*)))
                finally (progn
                          (ps:chain new-node (append-child (ps:chain document (create-text-node (ps:chain node-text (substring (+ (length query) index)))))))
                          (ps:chain *node-replacements*
                                    (push (list node new-node)))))))))

  (defun replace-original-nodes ()
    "Replace original nodes with recreated search nodes"
    (loop for node-pair in *node-replacements*
          do (ps:chain (elt node-pair 0) (replace-with (elt node-pair 1)))))

  (defun walk-document (node process-node)
    (when (and node (not (ps:chain node first-child)))
      (funcall process-node node (ps:lisp query)))
    (setf node (ps:chain node first-child))
    (loop while node
          do (walk-document node process-node)
          do (setf node (ps:chain node next-sibling))))

  (defun remove-search-nodes ()
    "Removes all the search elements"
    (ps:dolist (node (qsa document ".nyxt-search-node"))
      (ps:chain node (replace-with (aref *nodes* (ps:@ node id))))))

  (let ((*matches* (array))
        (*node-replacements* (array))
        (*identifier* 0))
    (add-stylesheet)
    (remove-search-nodes)
    (setf (ps:chain *nodes* identifier) 0)
    (walk-document (ps:chain document body) matches-from-node)
    (replace-original-nodes)
    (ps:chain |json| (stringify *matches*))))

(define-class match ()                  ; TODO: This conflicts with trivia.  Rename?
  ((identifier)
   (body)
   (buffer))
  (:accessor-name-transformer (hu.dwim.defclass-star:make-name-transformer name)))

(defclass multi-buffer-match (match) ())

(defmethod prompter:object-properties ((match match))
  (list :default (body match)
        :id (identifier match)))

(defmethod prompter:object-properties ((match multi-buffer-match))
  (list :default (body match)
        :id (identifier match)
        :buffer-id (id (buffer match))
        :buffer-title (title (buffer match))))

(defmethod object-string ((match match))
  (body match))

(defmethod object-display ((match match))
  (let* ((id (identifier match)))
    (format nil "~a …~a…" id (body match))))

(defmethod object-display ((match multi-buffer-match))
  (let* ((id (identifier match))
         (buffer-id (id (buffer match))))
    (format nil "~a:~a …~a…  ~a" buffer-id id (body match) (title (buffer match)))))

(defun matches-from-json (matches-json &optional (buffer (current-buffer)) (multi-buffer nil))
  (loop for element in (handler-case (cl-json:decode-json-from-string matches-json)
                         (error () nil))
        collect (make-instance (if multi-buffer 'multi-buffer-match 'match)
                               :identifier (cdr (assoc :identifier element))
                               :body (cdr (assoc :body element))
                               :buffer buffer)))

;; TODO: When prompter is in, turn `buffers' into a single buffer.
(defun match-suggestion-function (input &optional (buffers (list (current-buffer))) (case-sensitive-p nil))
  "Update the suggestions asynchronously via query-buffer."
  (when (> (length input) 2)            ; TODO: Replace by prompter's `requires-pattern'?
    (let ((input (str:replace-all " " " " input))
          (all-matches nil)
          (multi-buffer (if (> (list-length buffers) 1) t nil)))
      (dolist (buffer buffers)
        (with-current-buffer buffer
          (let* ((result (query-buffer
                          :query input
                          :case-sensitive-p case-sensitive-p))
                 (matches (matches-from-json
                           result buffer multi-buffer)))
            (setf all-matches (append all-matches matches)))))
      all-matches)))

(define-parenscript %remove-search-hints ()
  (defun qsa (context selector)
    "Alias of document.querySelectorAll"
    (ps:chain context (query-selector-all selector)))
  (defun remove-search-nodes ()
    "Removes all the search elements"
    (ps:dolist (node (qsa document ".nyxt-search-node"))
      (ps:chain node (replace-with (aref *nodes* (ps:@ node id))))))
  (remove-search-nodes))

(define-command search-buffer (&key (case-sensitive-p nil explicit-case-p))
  "Start a search on the current buffer."
  (apply #'search-over-buffers (list (current-buffer))
         (if explicit-case-p
             `(:case-sensitive-p ,case-sensitive-p)
             '())))

(define-command search-buffers (&key (case-sensitive-p nil explicit-case-p))
  "Show a prompt in the minibuffer that allows to choose
one or more buffers, and then start a search prompt that
searches over the selected buffer(s)."
  (let ((buffers (prompt-minibuffer
                  :input-prompt "Search buffer(s)"
                  :multi-selection-p t
                  :suggestion-function (buffer-suggestion-filter))))
    (apply #'search-over-buffers buffers
           (if explicit-case-p
               `(:case-sensitive-p ,case-sensitive-p)
               '()))))

(defun search-over-buffers (buffers &key (case-sensitive-p nil explicit-case-p))
  "Add search boxes for a given search string over the
provided buffers."
  (let* ((num-buffers (list-length buffers))
         (prompt-text
           (if (> num-buffers 1)
               (format nil "Search over ~d buffers for (3+ characters)" num-buffers)
               "Search for (3+ characters)")))
    (prompt-minibuffer
     :input-prompt prompt-text
     :suggestion-function
     #'(lambda (minibuffer)
         (unless explicit-case-p
           (setf case-sensitive-p (not (str:downcasep (input-buffer minibuffer)))))
         (match-suggestion-function (input-buffer minibuffer) buffers case-sensitive-p))
     :changed-callback
     (let ((subsequent-call nil))
       (lambda ()
         ;; when the minibuffer initially appears, we don't
         ;; want update-selection-highlight-hint to scroll
         ;; but on subsequent calls, it should scroll
         (update-selection-highlight-hint
          :scroll subsequent-call)
         (setf subsequent-call t)))
     :cleanup-function (lambda () (remove-focus))
     :history (nyxt::minibuffer-search-history *browser*))
    (update-selection-highlight-hint :follow t :scroll t)))

(define-command remove-search-hints ()
  "Remove all search hints."
  (%remove-search-hints))

(defun search-buffer-collector (&key case-sensitive-p)
  (lambda (preprocessed-suggestions source input)
    (declare (ignore preprocessed-suggestions))
    (mapcar (lambda (suggestion-value)
              (make-instance 'prompter:suggestion ; TODO: Can we have the `prompter' do this automatically for us?
                             :value suggestion-value
                             :properties (when (prompter:suggestion-property-function source)
                                           (funcall (prompter:suggestion-property-function source)
                                                    suggestion-value))))
            (match-suggestion-function input (list (source-buffer source))
                                       case-sensitive-p))))

(define-class search-buffer-source (prompter:prompter-source)
  ((case-sensitive-p nil)
   (source-buffer (current-buffer))
   (prompter:name "Search buffer")
   (prompter:must-match-p nil)
   (prompter:follow-p t)
   (prompter:filter nil)
   (prompter:filter-preprocessor (search-buffer-collector))
   (prompter:persistent-action (lambda (suggestion)
                                 (declare (ignore suggestion)) ; TODO: Pass suggestion?
                                 (prompt-buffer-selection-highlight-hint :scroll t)))
   (prompter:destructor (lambda (prompter source)
                          (declare (ignore prompter source))
                          (remove-focus))))
  (:accessor-name-transformer (hu.dwim.defclass-star:make-name-transformer name)))

(define-command search-buffer2 (&key case-sensitive-p)
  "Start a search on the current buffer."
  (prompt
   :prompter (list
              :prompt "Search for (3+ characters)" ; TODO: 2+ characters instead?  1?
              ;; TODO: List both case-sensitive and insensitive?
              :sources (list
                        (make-instance 'search-buffer-source :case-sensitive-p case-sensitive-p)))))

(define-command search-buffers2 (&key case-sensitive-p)
  "Start a search on the current buffer."
  ;; TODO: Fix following across buffers.
  (let ((buffers (prompt
                  :prompter (list
                             :prompt "Search buffer(s)"
                             :sources (list (make-instance 'buffer-source ; TODO: Define class?
                                                           :actions '()
                                                           :multi-selection-p t))))))
    (prompt
     :prompter (list
                :prompt "Search for (3+ characters)"
                :sources (mapcar (lambda (buffer)
                                   (make-instance 'search-buffer-source
                                                  :name (format nil "Search ~a" (if (url-empty-p (url buffer))
                                                                                    (title buffer)
                                                                                    (url buffer)))
                                                  :case-sensitive-p case-sensitive-p
                                                  :source-buffer buffer))
                                 buffers)))))
