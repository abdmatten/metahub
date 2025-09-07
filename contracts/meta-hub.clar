;; ----------------------------------------
;; Contract: meta-hub
;; A multi-layer hub for identity, subscriptions, bridging, prediction markets, DAO governance, and treasury.
;; ----------------------------------------

;; ------------------------------------------------------
;; DATA STRUCTURES
;; ------------------------------------------------------

;; Response types
(define-constant ERR-INVALID-USER (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INVALID-ID (err u103))

;; Contract Errors
(define-public (err-invalid-user) ERR-INVALID-USER)
(define-public (err-unauthorized) ERR-UNAUTHORIZED)
(define-public (err-invalid-amount) ERR-INVALID-AMOUNT)
(define-public (err-invalid-id) ERR-INVALID-ID)

;; Data vars
(define-data-var treasury uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var market-counter uint u0)

;; Identity type definition
(define-map identities { user: principal } { reputation: uint, verified: bool })

;; Membership type definition
(define-map memberships { member: principal } { tier: uint, expiry: uint })

;; Proposal type definition
(define-map proposals { id: uint } { creator: principal, description: (string-ascii 200), votes-for: uint, votes-against: uint, executed: bool })

;; Market type definition
(define-map markets { id: uint } { creator: principal, question: (string-ascii 200), yes-pool: uint, no-pool: uint, resolved: bool, outcome: (optional bool) })

;; Bridge lock type definition
(define-map bridge-locks { id: uint } { owner: principal, asset-id: (string-ascii 100), amount: uint, claimed: bool })

;; Helper functions for type checking
(define-private (is-valid-uint (value uint))
  (> value u0)
)

(define-private (is-contract-owner)
  (is-eq tx-sender (as-contract tx-sender))
)

(define-private (is-valid-id (id uint))
  (> id u0)
)

;; ------------------------------------------------------
;; IDENTITY (DID + Reputation)
;; ------------------------------------------------------

(define-public (register-identity (user principal))
  (begin
    ;; Assert user is the sender
    (asserts! (is-eq user tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-none (map-get? identities { user: user })) ERR-INVALID-USER)
    (map-set identities { user: user } { reputation: u0, verified: false })
    (ok true)
  )
)

(define-public (verify-identity (user principal))
  (begin
    ;; Assert sender is contract owner
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR-UNAUTHORIZED)
    (let 
      (
        (identity-map { user: user })
        (current-data (unwrap! (map-get? identities identity-map) ERR-INVALID-USER))
        (updated-data (merge current-data { verified: true }))
      )
      (map-set identities identity-map updated-data)
      (ok true)
    )
  )
)

(define-public (add-reputation (user principal) (points uint))
  (begin
    ;; Assert sender is contract owner and points are valid
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (> points u0) ERR-INVALID-AMOUNT)
    (let 
      (
        (identity-map { user: user })
        (current-data (unwrap! (map-get? identities identity-map) ERR-INVALID-USER))
        (updated-reputation (+ (get reputation current-data) points))
        (updated-data (merge current-data { reputation: updated-reputation }))
      )
      (map-set identities identity-map updated-data)
      (ok true)
    )
  )
)

;; ------------------------------------------------------
;; SUBSCRIPTIONS & MEMBERSHIPS
;; ------------------------------------------------------

(define-constant bronze-cost u10)
(define-constant silver-cost u50)
(define-constant gold-cost u100)

(define-public (subscribe (tier uint) (duration uint))
  (let
    (
      (cost (if (is-eq tier u1) bronze-cost (if (is-eq tier u2) silver-cost gold-cost)))
      (sender tx-sender)
    )
    (begin
      ;; Assert valid tier and duration
      (asserts! (and (>= tier u1) (<= tier u3)) ERR-INVALID-ID)
      (asserts! (> duration u0) ERR-INVALID-AMOUNT)
      ;; Process payment
      (try! (stx-transfer? cost sender (as-contract tx-sender)))
      (map-set memberships { member: sender } { tier: tier, expiry: (+ u0 duration) }) ;; Replace with actual block height when available
      (ok true)
    )
  )
)

;; ------------------------------------------------------
;; CROSS-CHAIN BRIDGE
;; ------------------------------------------------------

(define-public (lock-asset (lock-id uint) (asset-id (string-ascii 100)) (amount uint))
  (begin
    ;; Assert valid inputs
    (asserts! (> lock-id u0) ERR-INVALID-ID)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    ;; Assert lock doesn't exist
    (let 
      (
        (lock-map { id: lock-id })
        (new-lock { owner: tx-sender, asset-id: asset-id, amount: amount, claimed: false })
      )
      (asserts! (is-none (map-get? bridge-locks lock-map)) ERR-INVALID-ID)
      (map-set bridge-locks lock-map new-lock)
      (ok true)
    )
  )
)

(define-public (claim-asset (lock-id uint))
  (begin
    ;; Assert valid lock-id
    (asserts! (> lock-id u0) ERR-INVALID-ID)
    (let ((lock (unwrap! (map-get? bridge-locks { id: lock-id }) ERR-INVALID-ID)))
      ;; Assert caller is owner and lock is not claimed
      (asserts! (is-eq tx-sender (get owner lock)) ERR-UNAUTHORIZED)
      (asserts! (not (get claimed lock)) ERR-INVALID-ID)
      (map-set bridge-locks { id: lock-id }
        (merge lock { claimed: true })
      )
      (ok true)
    )
  )
)

;; ------------------------------------------------------
;; PREDICTION MARKETS
;; ------------------------------------------------------

(define-public (create-market (question (string-ascii 200)))
  (let ((id (+ (var-get market-counter) u1)))
    (begin
      ;; Assert valid question length
      (asserts! (> (len question) u0) ERR-INVALID-AMOUNT)
      (var-set market-counter id)
      (map-set markets { id: id } { creator: tx-sender, question: question, yes-pool: u0, no-pool: u0, resolved: false, outcome: none })
      (ok id)
    )
  )
)

(define-public (bet (market-id uint) (outcome bool) (amount uint))
  (begin
    ;; Assert valid inputs
    (asserts! (> market-id u0) ERR-INVALID-ID)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((market (unwrap! (map-get? markets { id: market-id }) ERR-INVALID-ID)))
      ;; Assert market is not resolved
      (asserts! (not (get resolved market)) ERR-INVALID-ID)
      (if outcome
        (map-set markets { id: market-id }
          (merge market { yes-pool: (+ (get yes-pool market) amount) })
        )
        (map-set markets { id: market-id }
          (merge market { no-pool: (+ (get no-pool market) amount) })
        )
      )
      (ok true)
    )
  )
)

(define-public (resolve-market (market-id uint) (outcome bool))
  (begin
    ;; Assert valid market-id
    (asserts! (> market-id u0) ERR-INVALID-ID)
    (let ((market (unwrap! (map-get? markets { id: market-id }) ERR-INVALID-ID)))
      ;; Assert caller is market creator and market is not resolved
      (asserts! (is-eq tx-sender (get creator market)) ERR-UNAUTHORIZED)
      (asserts! (not (get resolved market)) ERR-INVALID-ID)
      (map-set markets { id: market-id }
        (merge market { resolved: true, outcome: (some outcome) })
      )
      (ok true)
    )
  )
)

;; ------------------------------------------------------
;; DAO GOVERNANCE
;; ------------------------------------------------------

(define-public (create-proposal (description (string-ascii 200)))
  (let ((id (+ (var-get proposal-counter) u1)))
    (begin
      ;; Assert valid description length
      (asserts! (> (len description) u0) ERR-INVALID-AMOUNT)
      (var-set proposal-counter id)
      (map-set proposals { id: id } { creator: tx-sender, description: description, votes-for: u0, votes-against: u0, executed: false })
      (ok id)
    )
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (begin
    ;; Assert valid proposal-id
    (asserts! (> proposal-id u0) ERR-INVALID-ID)
    (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR-INVALID-ID)))
      ;; Assert proposal is not executed
      (asserts! (not (get executed proposal)) ERR-INVALID-ID)
      (if support
        (map-set proposals { id: proposal-id }
          (merge proposal { votes-for: (+ (get votes-for proposal) u1) })
        )
        (map-set proposals { id: proposal-id }
          (merge proposal { votes-against: (+ (get votes-against proposal) u1) })
        )
      )
      (ok true)
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (begin
    ;; Assert valid proposal-id
    (asserts! (> proposal-id u0) ERR-INVALID-ID)
    (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR-INVALID-ID)))
      ;; Assert proposal is not executed and caller is contract owner
      (asserts! (not (get executed proposal)) ERR-INVALID-ID)
      (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR-UNAUTHORIZED)
      (map-set proposals { id: proposal-id }
        (merge proposal { executed: true })
      )
      (ok true)
    )
  )
)

;; ------------------------------------------------------
;; TREASURY MANAGEMENT
;; ------------------------------------------------------

;; ------------------------------------------------------
;; TREASURY MANAGEMENT
;; ------------------------------------------------------

(define-public (fund-treasury (amount uint))
  (begin
    ;; Assert amount is valid
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury (+ (var-get treasury) amount))
    (ok true)
  )
)

(define-public (distribute-yield (recipient principal) (amount uint))
  (let 
    (
      (treasury-balance (var-get treasury))
    )
    (begin
      ;; Assert valid inputs
      (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR-UNAUTHORIZED)
      (asserts! (and (> amount u0) (<= amount treasury-balance)) ERR-INVALID-AMOUNT)
      ;; Transfer STX first to ensure success before updating state
      (asserts! (is-ok (as-contract (stx-transfer? amount tx-sender recipient))) ERR-INVALID-AMOUNT)
      ;; Update treasury balance
      (var-set treasury (- treasury-balance amount))
      (ok true)
    )
  )
)
