;; FundHive - Milestone-based Crowdfunding Platform
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-INITIALIZED (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-MILESTONE-NOT-COMPLETED (err u104))
(define-constant ERR-PROJECT-ENDED (err u105))

;; Data maps
(define-map projects 
    { project-id: uint }
    {
        owner: principal,
        target-amount: uint,
        current-amount: uint,
        end-block: uint,
        milestone-count: uint,
        is-active: bool
    }
)

(define-map milestones
    { project-id: uint, milestone-id: uint }
    {
        description: (string-ascii 256),
        amount: uint,
        completed: bool,
        released: bool
    }
)

(define-map contributions
    { project-id: uint, contributor: principal }
    { amount: uint }
)

;; Project counter
(define-data-var project-counter uint u0)

;; Administrative Functions
(define-public (create-project (target-amount uint) (end-block uint) (milestone-count uint))
    (let
        (
            (project-id (+ (var-get project-counter) u1))
        )
        (asserts! (> target-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> end-block block-height) ERR-INVALID-AMOUNT)
        (asserts! (> milestone-count u0) ERR-INVALID-AMOUNT)
        
        (map-set projects
            { project-id: project-id }
            {
                owner: tx-sender,
                target-amount: target-amount,
                current-amount: u0,
                end-block: end-block,
                milestone-count: milestone-count,
                is-active: true
            }
        )
        
        (var-set project-counter project-id)
        (ok project-id)
    )
)

(define-public (add-milestone (project-id uint) (milestone-id uint) (description (string-ascii 256)) (amount uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (<= milestone-id (get milestone-count project)) ERR-INVALID-AMOUNT)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            {
                description: description,
                amount: amount,
                completed: false,
                released: false
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
        )
        (asserts! (get is-active project) ERR-PROJECT-ENDED)
        (asserts! (<= block-height (get end-block project)) ERR-PROJECT-ENDED)
        (asserts! (> contribution-amount u0) ERR-INVALID-AMOUNT)
        
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        (map-set contributions
            { project-id: project-id, contributor: tx-sender }
            { amount: (default-to u0 (get amount (map-get? contributions { project-id: project-id, contributor: tx-sender }))) }
        )
        
        (map-set projects
            { project-id: project-id }
            (merge project { current-amount: (+ (get current-amount project) contribution-amount) })
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
        )
        (asserts! (get is-active project) ERR-PROJECT-ENDED)
        (asserts! (is-eq (get owner project) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get completed milestone)) ERR-MILESTONE-NOT-COMPLETED)
        
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { completed: true })
        )
        (ok true)
    )
)

(define-public (release-milestone-funds (project-id uint) (milestone-id uint))
    (let
        (
            (project (unwrap! (map-get? projects { project-id: project-id }) ERR-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
        )
        (asserts! (get is-active project) ERR-PROJECT-ENDED)
        (asserts! (get completed milestone) ERR-MILESTONE-NOT-COMPLETED)
        (asserts! (not (get released milestone)) ERR-MILESTONE-NOT-COMPLETED)
        
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get owner project))))
        
        (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { released: true })
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