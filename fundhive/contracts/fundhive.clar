;; FundHive - Milestone-based Crowdfunding Platform
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-INITIALIZED (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-MILESTONE-NOT-COMPLETED (err u104))
(define-constant ERR-PROJECT-ENDED (err u105))
(define-constant ERR-DEADLINE-PASSED (err u106))
(define-constant ERR-NO-REFUND-AVAILABLE (err u107))

;; Data maps
(define-map projects 
    { project-id: uint }
    {
        owner: principal,
        target-amount: uint,
        current-amount: uint,
        end-block: uint,
        milestone-count: uint,
        is-active: bool,
        last-milestone-deadline: uint,  ;; New field for tracking milestone deadlines
        total-milestones-completed: uint  ;; New field for progress tracking
    }
)

(define-map milestones
    { project-id: uint, milestone-id: uint }
    {
        description: (string-ascii 256),
        amount: uint,
        completed: bool,
        released: bool,
        deadline: uint,  ;; New field for milestone deadline
        completion-block: uint  ;; New field for tracking completion timestamp
    }
)

(define-map contributions
    { project-id: uint, contributor: principal }
    { 
        amount: uint,
        refunded: bool  ;; New field to track refund status
    }
)

;; Progress tracking
(define-map project-progress
    { project-id: uint }
    {
        funds-released: uint,
        total-contributors: uint,
        last-milestone-completion: uint
    }
)

;; Project counter
(define-data-var project-counter uint u0)

;; Administrative Functions
(define-public (create-project (target-amount uint) (end-block uint) (milestone-count uint) (milestone-deadline uint))
    (let
        (
            (project-id (+ (var-get project-counter) u1))
        )
        (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> end-block block-height) ERR-INVALID-AMOUNT)
        (asserts! (> milestone-count u0) ERR-INVALID-AMOUNT)
        (asserts! (>= milestone-deadline block-height) ERR-INVALID-AMOUNT)
        
        (map-set projects
            { project-id: project-id }
            {
                owner: tx-sender,
                target-amount: target-amount,
                current-amount: u0,
                end-block: end-block,
                milestone-count: milestone-count,
                is-active: true,
                last-milestone-deadline: milestone-deadline,
                total-milestones-completed: u0
            }
        )
        
        ;; Initialize progress tracking
        (map-set project-progress
            { project-id: project-id }
            {
                funds-released: u0,
                total-contributors: u0,
                last-milestone-completion: u0
            }
        )
        
        (var-set project-counter project-id)
        (ok project-id)
    )
)

(define-public (add-milestone (project-id uint) (milestone-id uint) (description (string-ascii 256)) (amount uint) (deadline uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= milestone-id (get milestone-count project)) ERR-INVALID-AMOUNT)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= deadline block-height) ERR-INVALID-AMOUNT)
        
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            {
                description: description,
                amount: amount,
                completed: false,
                released: false,
                deadline: deadline,
                completion-block: u0
            }
        )
        (ok true)
    )
)

;; Contribution Functions
(define-public (contribute (project-id uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
            (contribution-amount (stx-get-balance tx-sender))
            (current-progress (default-to 
                { funds-released: u0, total-contributors: u0, last-milestone-completion: u0 }
                (map-get? project-progress { project-id: project-id })))
        )
        (asserts! (get is-active project) ERR-PROJECT-ENDED)
        (asserts! (<= block-height (get end-block project)) ERR-PROJECT-ENDED)
        (asserts! (> contribution-amount u0) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        ;; Update contribution record
        (map-set contributions
            { project-id: project-id, contributor: tx-sender }
            { 
                amount: (+ (default-to u0 (get amount (map-get? contributions { project-id: project-id, contributor: tx-sender }))) contribution-amount),
                refunded: false
            }
        )
        
        ;; Update project and progress tracking
        (map-set projects
            { project-id: project-id }
            (merge project { current-amount: (+ (get current-amount project) contribution-amount) })
        )
        
        (map-set project-progress
            { project-id: project-id }
            (merge current-progress { total-contributors: (+ (get total-contributors current-progress) u1) })
        )
        
        (ok true)
    )
)

;; Milestone Management
(define-public (complete-milestone (project-id uint) (milestone-id uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
            (current-progress (default-to 
                { funds-released: u0, total-contributors: u0, last-milestone-completion: u0 }
                (map-get? project-progress { project-id: project-id })))
        )
        (asserts! (get is-active project) ERR-PROJECT-ENDED)
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get completed milestone)) ERR-MILESTONE-NOT-COMPLETED)
        (asserts! (<= block-height (get deadline milestone)) ERR-DEADLINE-PASSED)
        
        ;; Update milestone completion
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { 
                completed: true,
                completion-block: block-height
            })
        )
        
        ;; Update project progress
        (map-set projects
            { project-id: project-id }
            (merge project { 
                total-milestones-completed: (+ (get total-milestones-completed project) u1)
            })
        )
        
        (map-set project-progress
            { project-id: project-id }
            (merge current-progress { last-milestone-completion: block-height })
        )
        
        (ok true)
    )
)

(define-public (release-milestone-funds (project-id uint) (milestone-id uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
            (current-progress (default-to 
                { funds-released: u0, total-contributors: u0, last-milestone-completion: u0 }
                (map-get? project-progress { project-id: project-id })))
        )
        (asserts! (get is-active project) ERR-PROJECT-ENDED)
        (asserts! (get completed milestone) ERR-MILESTONE-NOT-COMPLETED)
        (asserts! (not (get released milestone)) ERR-MILESTONE-NOT-COMPLETED)
        
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get owner project))))
        
        ;; Update milestone and progress tracking
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { released: true })
        )
        
        (map-set project-progress
            { project-id: project-id }
            (merge current-progress { 
                funds-released: (+ (get funds-released current-progress) (get amount milestone))
            })
        )
        
        (ok true)
    )
)

;; Refund Functions
(define-public (claim-refund (project-id uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
            (contribution (unwrap! (map-get? contributions { project-id: project-id, contributor: tx-sender }) ERR-NOT-FOUND))
            (last-milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: (get milestone-count project) }) ERR-NOT-FOUND))
        )
        ;; Check if refund is available (missed deadline or project failed)
        (asserts! (or
            (> block-height (get last-milestone-deadline project))
            (> block-height (get deadline last-milestone))
        ) ERR-NO-REFUND-AVAILABLE)
        (asserts! (not (get refunded contribution)) ERR-NO-REFUND-AVAILABLE)
        
        ;; Process refund
        (try! (as-contract (stx-transfer? (get amount contribution) tx-sender tx-sender)))
        
        ;; Mark contribution as refunded
        (map-set contributions
            { project-id: project-id, contributor: tx-sender }
            (merge contribution { refunded: true })
        )
        
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-project (project-id uint))
    (map-get? projects { project-id: project-id })
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
    (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-contribution (project-id uint) (contributor principal))
    (map-get? contributions { project-id: project-id, contributor: contributor })
)

(define-read-only (get-project-progress (project-id uint))
    (map-get? project-progress { project-id: project-id })
)

(define-read-only (get-refund-eligibility (project-id uint) (contributor principal))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
            (contribution (unwrap! (map-get? contributions { project-id: project-id, contributor: contributor }) ERR-NOT-FOUND))
            (last-milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: (get milestone-count project) }) ERR-NOT-FOUND))
        )
        (ok (and
            (not (get refunded contribution))
            (or
                (> block-height (get last-milestone-deadline project))
                (> block-height (get deadline last-milestone))
            )
        ))
    )
)